/**
 * Controller for the on-page document upload component (dlPageUpload).
 *
 * Page-side upload flow (Option A2): the visitor uploads their ID and proof of
 * address on the DMV site. This creates a fresh Application (tied to the
 * Jay Walker golden Contact for the demo) to attach the files to; the agent
 * later discovers that Application and extracts the details.
 */
public with sharing class DLPageUploadController {

    // Golden demo contact — Jay Walker. Every uploaded application is tied to it.
    private static final Id GOLDEN_CONTACT_ID = '003gL00000zSE1hQAG';

    /**
     * Creates a Draft Application for the current upload session and returns its
     * Id, so lightning-file-upload can attach files directly to it.
     */
    @AuraEnabled
    public static Id createApplicationForUpload() {
        Application__c app = new Application__c(
            Status__c = 'Draft',
            Contact__c = GOLDEN_CONTACT_ID
        );
        insert app;
        return app.Id;
    }
}
