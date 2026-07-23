/**
 * Orchestrator invoked by the autolaunched Flow L3_DocAI_ProcessDocuments.
 *
 * For each uploaded ContentDocumentId:
 *   1. Run BOTH Doc AI configs (passport + powerBill) to get field values.
 *   2. Categorize the document (Passport / Power Bill / Other) from those values.
 *   3. Keep the output that matches the category.
 * After all docs: write the combined result to a single record and return JSON
 * outputs the LWC can consume.
 */
public class L3_DocAI_ProcessDocuments {

    @InvocableMethod(label='[DocAI] Process Documents' category='Document AI')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(processOne(req));
        }
        return results;
    }

    private static Result processOne(Request req) {
        Result out = new Result();
        for (Id docId : req.contentDocumentIds) {
            String passportJson = safeExtract(docId, 'passport');
            String billJson = safeExtract(docId, 'powerBill');
            String category = L3_DocAI_Categorizer.categorize(passportJson, billJson);

            if (category == L3_DocAI_Categorizer.PASSPORT) {
                out.passportJson = passportJson;
                out.passportDocId = docId;
            } else if (category == L3_DocAI_Categorizer.POWER_BILL) {
                out.powerBillJson = billJson;
                out.powerBillDocId = docId;
            } else {
                out.otherDocIds.add(docId);
            }
        }
        // Write the combined data to a single record (Contact by default).
        out.recordId = writeRecord(out);
        out.summaryJson = JSON.serialize(new Map<String, Object>{
            'recordId' => out.recordId,
            'passport' => out.passportJson,
            'powerBill' => out.powerBillJson,
            'otherCount' => out.otherDocIds.size()
        });
        return out;
    }

    private static String safeExtract(Id docId, String configName) {
        L3_DocAI_ExtractData.Request r = new L3_DocAI_ExtractData.Request();
        r.contentDocumentId = docId;
        r.docAIConfigIdOrName = configName;
        List<L3_DocAI_ExtractData.Result> res =
            L3_DocAI_ExtractData.execute(new List<L3_DocAI_ExtractData.Request>{ r });
        return (res[0].isSuccess) ? res[0].extractedDataJson : null;
    }

    /** Create one Contact from whatever was captured. Returns the new record Id. */
    private static Id writeRecord(Result r) {
        String fullName;
        String dob;
        String address;

        if (String.isNotBlank(r.passportJson)) {
            Map<String, String> p = fieldValues(r.passportJson);
            fullName = p.get('name');
            dob = p.get('dateOfBirth');
        }
        if (String.isNotBlank(r.powerBillJson)) {
            Map<String, String> b = fieldValues(r.powerBillJson);
            address = b.get('address');
        }
        if (String.isBlank(fullName) && String.isBlank(address)) {
            return null; // nothing worth writing
        }

        Contact c = new Contact();
        c.LastName = String.isNotBlank(fullName) ? fullName : 'Unknown (Doc AI)';
        if (String.isNotBlank(address)) {
            c.MailingStreet = address;
        }
        if (String.isNotBlank(dob)) {
            c.Description = 'DOB (from passport): ' + dob;
        }
        insert c;
        return c.Id;
    }

    /** Flatten Doc AI extracted JSON to key -> value strings. */
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

    public class Request {
        @InvocableVariable(required=true label='Content Document Ids')
        public List<Id> contentDocumentIds;
    }

    public class Result {
        @InvocableVariable(label='Passport JSON') public String passportJson;
        @InvocableVariable(label='Power Bill JSON') public String powerBillJson;
        @InvocableVariable(label='Passport Doc Id') public Id passportDocId;
        @InvocableVariable(label='Power Bill Doc Id') public Id powerBillDocId;
        @InvocableVariable(label='Created Record Id') public Id recordId;
        @InvocableVariable(label='Summary JSON') public String summaryJson;
        @InvocableVariable(label='Uncategorized Doc Ids') public List<Id> otherDocIds = new List<Id>();
    }
}