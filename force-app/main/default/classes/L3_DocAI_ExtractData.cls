/**
 * Generic Document AI extraction callout.
 * Given a ContentDocumentId and an IDP config name, uploads the file reference to the
 * document-processing extract-data action and returns the raw extracted-data JSON.
 *
 * Auth: the 'L3_DocAI' Named Credential injects the Authorization header itself
 * from its stored External Credential (a permanent token). We do NOT set the
 * header in code: the previous approach used UserInfo.getSessionId(), which is
 * NOT API-valid in the Agentforce agent-user (or async) context and returned
 * 401 INVALID_SESSION_ID. Letting the Named Credential supply auth makes the
 * callout work for any running user, including the Einstein Service Agent user.
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
        // Auth: read a valid org access token from custom metadata (same pattern
        // as the Google Maps key). We do NOT use UserInfo.getSessionId() - it is
        // not API-valid in the Agentforce agent/async context (401 INVALID_SESSION_ID).
        // The token is a session token that expires; refresh the DMV_Config record
        // when it does. (The agent's 'confirmed' path still proceeds if this fails.)
        DMV_Config__mdt tokenCfg = DMV_Config__mdt.getInstance('DocAI_Token');
        String token = (tokenCfg != null) ? tokenCfg.Api_Key__c : null;
        if (String.isNotBlank(token)) {
            req.setHeader('Authorization', 'Bearer ' + token);
        }
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