/**
 * Invocable action for the Drivers License Agent — DOC AI STUB + geocoding.
 *
 * ⚠️ EXTRACTION IS A STUB: real document interpretation (passport + power-bill
 * Doc AI readers) is being built separately. For now this returns plausible
 * extracted details. The extracted address IS geocoded for real (Google
 * Geocoding via the DMV_Maps named credential) so downstream office ranking has
 * coordinates. Results are written to the Application__c record.
 *
 * Swap the extraction block for real reader invocation later — the Application
 * write + geocode + I/O contract can stay the same.
 */
public without sharing class DLDocumentProcessor {

    public class Request {
        @InvocableVariable(
            label='Application Id'
            description='The Application whose uploaded documents should be interpreted.'
            required=true
        )
        public String applicationId;
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
        label='Extract Documents And Update Application'
        description='STUB: interprets uploaded identity documents, extracts personal details, geocodes the address, and updates the Application.'
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
        Application__c app;
        for (Application__c a : [
            SELECT Id, First_Name__c, Last_Name__c, Birthdate__c, Street__c, City__c, State__c, Postal_Code__c
            FROM Application__c WHERE Id = :req.applicationId LIMIT 1
        ]) {
            app = a;
        }
        if (app == null) {
            res.success = false;
            res.message = 'Could not find the application to update.';
            return res;
        }

        // Find the documents attached to this Application and identify each by
        // filename: passport.png -> passport reader, powerbill.png -> power-bill
        // reader. (File discovery + routing is real; only the OCR call is stubbed.)
        Id passportDocId, powerbillDocId;
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :app.Id
        ]) {
            String title = (link.ContentDocument.Title == null) ? '' : link.ContentDocument.Title.toLowerCase();
            if (title.contains('passport')) {
                passportDocId = link.ContentDocumentId;
            } else if (title.contains('powerbill') || title.contains('power_bill') || title.contains('power bill')) {
                powerbillDocId = link.ContentDocumentId;
            }
        }
        if (passportDocId == null && powerbillDocId == null) {
            res.success = false;
            res.message = 'We could not find your uploaded documents. Please upload passport.png and powerbill.png, then let me know.';
            return res;
        }

        // Passport reader -> name + birthday. Power-bill reader -> address.
        Map<String, String> passportData = readPassport(passportDocId);
        Map<String, String> powerbillData = readPowerbill(powerbillDocId);

        res.firstName = passportData.get('firstName');
        res.lastName = passportData.get('lastName');
        res.birthdate = passportData.get('birthdate');
        res.street = powerbillData.get('street');
        res.city = powerbillData.get('city');
        res.state = powerbillData.get('state');
        res.postalCode = powerbillData.get('postalCode');

        // Geocode the extracted address FIRST (callout must precede DML).
        String fullAddress = res.street + ', ' + res.city + ', ' + res.state + ' ' + res.postalCode;
        Decimal[] latLng = geocode(fullAddress);

        app.First_Name__c = res.firstName;
        app.Last_Name__c = res.lastName;
        app.Birthdate__c = Date.valueOf(res.birthdate);
        app.Street__c = res.street;
        app.City__c = res.city;
        app.State__c = res.state;
        app.Postal_Code__c = res.postalCode;
        if (latLng != null) {
            app.Latitude__c = latLng[0];
            app.Longitude__c = latLng[1];
        }
        app.Status__c = 'Details Confirmed';
        update app;

        res.success = true;
        res.message = 'Extracted personal details, geocoded the address, and updated the application (extraction is a STUB).';
        return res;
    }

    /**
     * ⚠️ STUB — Passport Doc AI reader. Given the passport.png ContentDocument
     * Id, this will invoke the "passport" Document AI reader to extract the
     * holder's name and birthday. For now it returns fixed values. Replace the
     * body with the real reader invocation; the return contract can stay.
     */
    private static Map<String, String> readPassport(Id contentDocumentId) {
        // TODO: invoke passport Document AI reader against contentDocumentId.
        return new Map<String, String>{
            'firstName' => 'Jane',
            'lastName' => 'Doe',
            'birthdate' => '1990-05-14'
        };
    }

    /**
     * ⚠️ STUB — Power-bill Doc AI reader. Given the powerbill.png ContentDocument
     * Id, this will invoke the "powerbill" Document AI reader to extract the
     * service address. For now it returns fixed values. Replace the body with the
     * real reader invocation; the return contract can stay.
     */
    private static Map<String, String> readPowerbill(Id contentDocumentId) {
        // TODO: invoke power-bill Document AI reader against contentDocumentId.
        return new Map<String, String>{
            'street' => '1 Shields Ave',
            'city' => 'Davis',
            'state' => 'CA',
            'postalCode' => '95616'
        };
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
