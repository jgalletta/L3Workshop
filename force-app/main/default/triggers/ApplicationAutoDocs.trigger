/**
 * Auto-attaches the golden demo documents (Jay Walker passport + power bill) to
 * every new Draft Application, so the agent can extract details without relying
 * on a browser-side file upload (which is blocked by the org's CSRF/UI-API gap).
 *
 * Fires only for Draft applications that don't already have files, and only when
 * they belong to the Jay Walker golden contact — so real applications with real
 * uploads are never touched.
 */
trigger ApplicationAutoDocs on Application__c (after insert) {
    Set<Id> appIds = new Set<Id>();
    for (Application__c a : Trigger.new) {
        if (a.Status__c == 'Draft') {
            appIds.add(a.Id);
        }
    }
    if (!appIds.isEmpty()) {
        ApplicationAutoDocsService.attachGoldenDocs(appIds);
    }
}
