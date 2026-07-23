/**
 * REST endpoint for the DMV portal document upload (single call, server-side).
 *
 *   POST /services/apexrest/dmvUpload
 *   Body: { "files": [ { "title": "...", "fileName": "...", "base64": "..." }, ... ] }
 *
 * Runs entirely as the unauthenticated Experience-site guest user. The guest
 * can create the Application and its own ContentVersions (which auto-create the
 * ContentDocumentLinks), so the whole flow works without the guest needing
 * direct object create access on ContentDocumentLink.
 *   1. Create an Application (tied to the Jay Walker golden contact)
 *   2. Save each uploaded file as a ContentVersion published to the Application
 *      (FirstPublishLocationId creates the ContentDocumentLink)
 *   3. Return the new Application's Id + number
 *
 * Document AI extraction is intentionally OUT OF SCOPE here: the guest user has
 * no access to the L3_DocAI_* classes, so extraction is wired up separately.
 * This endpoint's contract is just "submit succeeds, app created, files linked".
 */
@RestResource(urlMapping='/dmvUpload/*')
global without sharing class DLApplicationUploadResource {

    global class UploadFile {
        global String title;
        global String fileName;
        global String base64;
    }

    global class UploadResult {
        global Boolean success;
        global String applicationId;
        global String applicationNumber;
        global String firstName;
        global String lastName;
        global String birthdate;
        global String street;
        global String message;
    }

    private static final Id GOLDEN_CONTACT_ID = '003gL00000zSE1hQAG';

    @HttpPost
    global static UploadResult upload() {
        UploadResult res = new UploadResult();
        res.success = false;

        // Parse the request body.
        List<UploadFile> files;
        try {
            String body = RestContext.request.requestBody.toString();
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            files = (List<UploadFile>) JSON.deserialize(
                JSON.serialize(parsed.get('files')), List<UploadFile>.class
            );
        } catch (Exception e) {
            res.message = 'Could not read the uploaded files: ' + e.getMessage();
            return res;
        }
        if (files == null || files.isEmpty()) {
            res.message = 'No files were provided.';
            return res;
        }

        // Create the Application, then save each uploaded file as a ContentVersion
        // published to it. The guest user owns the ContentVersions it creates, and
        // FirstPublishLocationId auto-creates the ContentDocumentLink to the app —
        // this is the one write path that works for the unauthenticated guest.
        Application__c app = new Application__c(Status__c = 'Draft', Contact__c = GOLDEN_CONTACT_ID);
        insert app;

        List<ContentVersion> cvs = new List<ContentVersion>();
        for (UploadFile f : files) {
            if (String.isBlank(f.base64)) continue;
            cvs.add(new ContentVersion(
                Title = (f.title != null ? f.title : 'document'),
                PathOnClient = (f.fileName != null ? f.fileName : 'document.png'),
                VersionData = EncodingUtil.base64Decode(f.base64),
                FirstPublishLocationId = app.Id
            ));
        }
        if (cvs.isEmpty()) {
            res.message = 'The uploaded files were empty.';
            return res;
        }
        insert cvs;

        res.applicationId = app.Id;
        for (Application__c a : [SELECT Name FROM Application__c WHERE Id = :app.Id]) {
            res.applicationNumber = a.Name;
        }

        // NOTE: Document AI extraction is intentionally NOT run here. The guest
        // user lacks access to the L3_DocAI_* classes, so extraction is a separate
        // piece to be wired up later. For now the goal is simply: submit succeeds,
        // Application is created, and the uploaded files are linked to it.
        res.success = true;
        res.message = 'Documents uploaded (' + cvs.size() + '). Your application has been created.';
        return res;
    }
}
