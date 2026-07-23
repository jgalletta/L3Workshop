/**
 * Generic Document AI extraction callout.
 * Given a ContentDocumentId and an IDP config name, uploads the file reference to the
 * document-processing extract-data action and returns the raw extracted-data JSON.
 *
 * Auth: self-referential Named Credential 'L3_DocAI' -> this org's My Domain,
 * authenticating as the running user (no external secrets required).
 */
public class L3_DocAI_ExtractData {
    private static final String EXTRACT_DATA_ENDPOINT = '/services/data/v64.0/ssot/document-processing/actions/extract-data';
    private static final String NAMED_CREDENTIAL = 'callout:L3_DocAI';

    @InvocableMethod(label='[DocAI] Extract Data with Configuration')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result result = new Result();
            try {
                ContentVersion cv = [
                    SELECT Id, FileExtension FROM ContentVersion
                    WHERE ContentDocumentId = :req.contentDocumentId AND IsLatest = true
                    LIMIT 1
                ];
                String mimeType;
                switch on cv.FileExtension {
                    when 'png', 'jpg', 'jpeg' { mimeType = 'image/' + cv.FileExtension; }
                    when 'pdf' { mimeType = 'application/pdf'; }
                    when else { mimeType = 'application/octet-stream'; }
                }
                result.extractedDataJson = extractData(cv.Id, mimeType, req.docAIConfigIdOrName);
                result.isSuccess = true;
            } catch (Exception e) {
                result.isSuccess = false;
                result.errorMessage = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    public class Request {
        @InvocableVariable(required=true) public Id contentDocumentId;
        @InvocableVariable(required=true) public String docAIConfigIdOrName;
    }
    public class Result {
        @InvocableVariable public Boolean isSuccess;
        @InvocableVariable public String extractedDataJson;
        @InvocableVariable public String errorMessage;
    }

    private static String extractData(String fileId, String mimeType, String cfg) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + EXTRACT_DATA_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        // Same-org self-referential auth: present the running user's session.
        // Works in synchronous/Flow-invoked context (interactive Screen Flow).
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setTimeout(120000);
        req.setBody(JSON.serialize(new Map<String, Object>{
            'idpConfigurationIdOrName' => cfg,
            'files' => new List<Object>{
                new Map<String, Object>{ 'fileId' => fileId, 'mimeType' => mimeType }
            }
        }));
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (body.containsKey('data')) {
                return JSON.serialize(body.get('data'));
            }
            return res.getBody();
        }
        throw new CalloutException('Extract Error (' + res.getStatusCode() + '): ' + res.getBody());
    }
}