// without sharing: a service agent must be able to retrieve any case by its
// number regardless of record ownership/sharing (Case uses a private model).
public without sharing class CaseLookup {
    public class Request {
        @InvocableVariable(
            label='Case Number'
            description='The case number of the support case to retrieve, for example 00001234.'
            required=true
        )
        public String caseNumber;
    }

    public class Result {
        @InvocableVariable(
            label='Case Number'
            description='The case number of the retrieved case.'
        )
        public String caseNumber;
        @InvocableVariable(
            label='Subject'
            description='The subject of the case.'
        )
        public String subject;
        @InvocableVariable(
            label='Status'
            description='The current status of the case.'
        )
        public String status;
        @InvocableVariable(
            label='Priority'
            description='The priority of the case.'
        )
        public String priority;
        @InvocableVariable(
            label='Origin'
            description='The origin of the case.'
        )
        public String origin;
        @InvocableVariable(
            label='Description'
            description='The description of the case.'
        )
        public String description;
        @InvocableVariable(
            label='Found'
            description='Whether a case was found for the given case number.'
        )
        public Boolean found;
    }

    @InvocableMethod(
        label='Retrieve Case'
        description='Retrieves a support case by its case number.'
    )
    public static List<Result> retrieveCase(List<Request> requests) {
        // Collect the requested case numbers (bulkified).
        Set<String> caseNumbers = new Set<String>();
        for (Request req : requests) {
            if (String.isNotBlank(req.caseNumber)) {
                caseNumbers.add(req.caseNumber.trim());
            }
        }

        // Query matching cases and index by case number.
        Map<String, Case> casesByNumber = new Map<String, Case>();
        if (!caseNumbers.isEmpty()) {
            for (Case c : [
                SELECT CaseNumber, Subject, Status, Priority, Origin, Description
                FROM Case
                WHERE CaseNumber IN :caseNumbers
            ]) {
                casesByNumber.put(c.CaseNumber, c);
            }
        }

        // Build one Result per request, preserving order.
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            String key = (req.caseNumber == null) ? null : req.caseNumber.trim();
            Case c = (key == null) ? null : casesByNumber.get(key);
            if (c != null) {
                r.found = true;
                r.caseNumber = c.CaseNumber;
                r.subject = c.Subject;
                r.status = c.Status;
                r.priority = c.Priority;
                r.origin = c.Origin;
                r.description = c.Description;
            } else {
                r.found = false;
                r.caseNumber = key;
                r.subject = '';
                r.status = '';
                r.priority = '';
                r.origin = '';
                r.description = '';
            }
            results.add(r);
        }
        return results;
    }
}
