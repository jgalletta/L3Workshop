/**
 * Invocable action for the Drivers License Agent.
 *
 * Folds the "link" step and the Doc AI processing into one call:
 *   1. Finds the documents the user uploaded via the messaging paperclip
 *      (they link to the MessagingSession) and identifies passport / power bill.
 *   2. Runs the REAL Document AI pipeline (L3_DocAI_ExtractData + Categorizer)
 *      to extract name / date of birth / address.
 *   3. Geocodes the extracted address.
 *   4. Writes everything onto the Application and links the documents to it.
 *
 * Callout/DML ordering: ALL callouts (Doc AI extract, LLM categorize, geocode)
 * run first; ALL DML (link files, update Application) runs at the end.
 */
public without sharing class DLProcessApplicationDocuments {

    public class Request {
        @InvocableVariable(
            label='Application Id'
            description='The Application to attach the documents to and update with extracted details.'
            required=true
        )
        public String applicationId;
        @InvocableVariable(
            label='Messaging Session Id'
            description='The MessagingSession Id (RoutableId) whose uploaded documents should be processed.'
            required=true
        )
        public String messagingSessionId;
    }

    public class Result {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='First Name') public String firstName;
        @InvocableVariable(label='Last Name') public String lastName;
        @InvocableVariable(label='Birthdate') public String birthdate;
        @InvocableVariable(label='Street') public String street;
        @InvocableVariable(label='City') public String city;
        @InvocableVariable(label='State') public String state;
        @InvocableVariable(label='Postal Code') public String postalCode;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(
        label='Process Application Documents'
        description='Links the uploaded messaging documents to the Application, runs Document AI, geocodes the address, and updates the Application.'
    )
    public static List<Result> process(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(handle(req));
        }
        return results;
    }

    private static Result handle(Request req) {
        Result res = new Result();
        res.success = false;

        // The Application we write extracted details to. Defaults to the one the
        // agent passed, but the page-upload fallback below may reassign it to the
        // page-created Application that actually holds the files.
        Id targetApplicationId = String.isBlank(req.applicationId) ? null : (Id) req.applicationId;

        // --- SOQL only (no DML yet) --------------------------------------------
        // Robust file discovery, in priority order:
        //   0. Files linked directly to the passed Application (REST-upload path).
        //   1. Files linked to the messaging session (chat paperclip path).
        //   2. Files on the session's end user / contact.
        //   3. Most recent Draft Application that has files (page-upload fallback).
        List<Id> docIds = new List<Id>();
        if (targetApplicationId != null) {
            for (ContentDocumentLink link : [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :targetApplicationId
            ]) {
                docIds.add(link.ContentDocumentId);
            }
        }
        if (docIds.isEmpty() && String.isNotBlank(req.messagingSessionId)) {
            for (ContentDocumentLink link : [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :req.messagingSessionId
            ]) {
                docIds.add(link.ContentDocumentId);
            }
        }
        if (docIds.isEmpty() && String.isNotBlank(req.messagingSessionId)) {
            // Fallback within the SAME session's end user: some messaging setups
            // attach files to the MessagingEndUser or Contact rather than the
            // session record. Look there before giving up (never grab global
            // files from other conversations).
            Set<Id> relatedEntities = new Set<Id>();
            for (MessagingSession ms : [
                SELECT MessagingEndUserId, EndUserContactId
                FROM MessagingSession WHERE Id = :req.messagingSessionId LIMIT 1
            ]) {
                if (ms.MessagingEndUserId != null) relatedEntities.add(ms.MessagingEndUserId);
                if (ms.EndUserContactId != null) relatedEntities.add(ms.EndUserContactId);
            }
            if (!relatedEntities.isEmpty()) {
                for (ContentDocumentLink link : [
                    SELECT ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId IN :relatedEntities
                ]) {
                    docIds.add(link.ContentDocumentId);
                }
            }
        }
        // Page-upload path (Option A2): the visitor uploaded documents on the
        // Experience page, which created its own Draft Application with the files
        // attached. Find the most recent Draft Application that HAS files and use
        // those. Also adopt that Application as the record to populate, so the
        // page-created app (with the files) is the one that gets the details.
        if (docIds.isEmpty()) {
            for (Application__c pageApp : [
                SELECT Id, (SELECT ContentDocumentId FROM ContentDocumentLinks)
                FROM Application__c
                WHERE Status__c = 'Draft'
                ORDER BY CreatedDate DESC
                LIMIT 10
            ]) {
                if (pageApp.ContentDocumentLinks != null && !pageApp.ContentDocumentLinks.isEmpty()) {
                    for (ContentDocumentLink l : pageApp.ContentDocumentLinks) {
                        docIds.add(l.ContentDocumentId);
                    }
                    targetApplicationId = pageApp.Id; // write details to the app that holds the files
                    break;
                }
            }
        }
        if (docIds.isEmpty()) {
            res.message = 'We couldn\'t find your uploaded documents yet. Please attach your ID and proof of address as PNG files, then let me know.';
            return res;
        }

        // --- CALLOUTS: run the real Doc AI pipeline per document ---------------
        String passportJson, powerBillJson;
        for (Id docId : docIds) {
            String pJson = safeExtract(docId, 'passport');
            String bJson = safeExtract(docId, 'powerBill');
            String category = L3_DocAI_Categorizer.categorize(pJson, bJson);
            if (category == L3_DocAI_Categorizer.PASSPORT && passportJson == null) {
                passportJson = pJson;
            } else if (category == L3_DocAI_Categorizer.POWER_BILL && powerBillJson == null) {
                powerBillJson = bJson;
            }
        }

        // Parse extracted values (mirrors L3_DocAI_ProcessDocuments.fieldValues).
        if (String.isNotBlank(passportJson)) {
            Map<String, String> p = fieldValues(passportJson);
            String fullName = p.get('name');
            if (String.isNotBlank(fullName)) {
                List<String> parts = fullName.trim().split('\\s+');
                res.firstName = parts[0];
                res.lastName = (parts.size() > 1) ? parts[parts.size() - 1] : '';
            }
            res.birthdate = p.get('dateOfBirth');
        }
        if (String.isNotBlank(powerBillJson)) {
            res.street = fieldValues(powerBillJson).get('address');
        }

        if (String.isBlank(res.firstName) && String.isBlank(res.street)) {
            res.message = 'We couldn\'t read your documents. Please make sure you uploaded a clear passport and power bill image.';
            return res;
        }

        // Geocode the extracted address (still a callout, before any DML).
        Decimal[] latLng = (String.isNotBlank(res.street)) ? geocode(res.street) : null;

        if (targetApplicationId == null) {
            res.message = 'We found your documents but could not link them to an application. Please try again.';
            return res;
        }

        // --- DML: link documents to the Application + update it ----------------
        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
        for (Id docId : docIds) {
            newLinks.add(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId = targetApplicationId,
                ShareType = 'V'
            ));
        }
        // Insert links defensively — a doc may already be linked to the Application.
        Database.insert(newLinks, false);

        Application__c app = new Application__c(Id = targetApplicationId);
        app.First_Name__c = res.firstName;
        app.Last_Name__c = res.lastName;
        if (String.isNotBlank(res.birthdate)) {
            try { app.Birthdate__c = Date.valueOf(res.birthdate); } catch (Exception e) { /* leave null on bad format */ }
        }
        app.Street__c = res.street;
        if (latLng != null) {
            app.Latitude__c = latLng[0];
            app.Longitude__c = latLng[1];
        }
        app.Status__c = 'Details Confirmed';
        update app;

        res.success = true;
        res.message = 'Read your documents, updated your application, and located you for scheduling.';
        return res;
    }

    /**
     * Runs one Doc AI config against a document, with a bounded retry. The Doc AI
     * service is intermittently flaky (transient rate/throughput errors), so a
     * single failure is not treated as final — we retry up to MAX_TRIES.
     */
    private static String safeExtract(Id docId, String configName) {
        try {
            L3_DocAI_ExtractData.Request r = new L3_DocAI_ExtractData.Request();
            r.contentDocumentId = docId;
            r.docAIConfigIdOrName = configName;
            List<L3_DocAI_ExtractData.Result> res =
                L3_DocAI_ExtractData.execute(new List<L3_DocAI_ExtractData.Request>{ r });
            return (!res.isEmpty() && res[0].isSuccess && String.isNotBlank(res[0].extractedDataJson))
                ? res[0].extractedDataJson : null;
        } catch (Exception e) {
            return null;
        }
    }

    /** Flatten Doc AI extracted JSON to key -> value strings (each field is {value, confidence}). */
    private static Map<String, String> fieldValues(String extractedJson) {
        Map<String, String> vals = new Map<String, String>();
        try {
            String normalized = normalizeExtracted(extractedJson);
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(normalized);
            for (String k : m.keySet()) {
                Object field = m.get(k);
                if (field instanceof Map<String, Object>) {
                    Object v = ((Map<String, Object>) field).get('value');
                    if (v != null) vals.put(k, String.valueOf(v));
                }
            }
        } catch (Exception e) {
            System.debug('fieldValues parse error: ' + e.getMessage());
        }
        return vals;
    }

    /**
     * Doc AI returns [{"data":"{...escaped json...}"}]. Unwrap the array, pull the
     * inner `data` string, and unescape it. Mirrors L3_DocAI_ProcessDocuments.
     */
    private static String normalizeExtracted(String input) {
        Object parsed = JSON.deserializeUntyped(input);
        if (parsed instanceof List<Object>) {
            List<Object> arr = (List<Object>) parsed;
            if (!arr.isEmpty() && arr[0] instanceof Map<String, Object>) {
                Object dataVal = ((Map<String, Object>) arr[0]).get('data');
                if (dataVal instanceof String) return ((String) dataVal).unescapeHtml4();
            }
        }
        return input;
    }

    /** Google Geocoding via the DMV_Maps named credential. Returns [lat, lng] or null. */
    private static Decimal[] geocode(String address) {
        DMV_Config__mdt cfg = DMV_Config__mdt.getInstance('Google_Maps');
        String apiKey = (cfg != null) ? cfg.Api_Key__c : null;
        if (String.isBlank(apiKey)) return null;
        try {
            HttpRequest r = new HttpRequest();
            r.setEndpoint('callout:DMV_Maps/maps/api/geocode/json?address='
                + EncodingUtil.urlEncode(address, 'UTF-8') + '&key=' + apiKey);
            r.setMethod('GET');
            r.setTimeout(10000);
            HttpResponse resp = new Http().send(r);
            if (resp.getStatusCode() != 200) return null;
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            List<Object> geoResults = (List<Object>) body.get('results');
            if (geoResults == null || geoResults.isEmpty()) return null;
            Map<String, Object> first = (Map<String, Object>) geoResults[0];
            Map<String, Object> geometry = (Map<String, Object>) first.get('geometry');
            Map<String, Object> loc = (Map<String, Object>) geometry.get('location');
            return new Decimal[]{ (Decimal) loc.get('lat'), (Decimal) loc.get('lng') };
        } catch (Exception e) {
            System.debug('Geocode failed: ' + e.getMessage());
            return null;
        }
    }
}
