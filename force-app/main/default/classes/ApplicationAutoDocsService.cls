/**
 * Attaches the golden demo documents (Jay Walker passport + power bill) to new
 * Draft Applications and triggers Doc AI extraction — all server-side, so the
 * flow works regardless of the browser CSRF/UI-API limitation.
 *
 * Runs async (@future) because it's invoked from a trigger and performs DML +
 * callouts. Idempotent: skips applications that already have files linked.
 */
public without sharing class ApplicationAutoDocsService {

    // Golden demo documents that extract Jay Walker's details.
    private static final Id GOLDEN_PASSPORT_DOC = '069gL00000BZaqHQAT';
    private static final Id GOLDEN_POWERBILL_DOC = '069gL00000BZartQAD';

    public static void attachGoldenDocs(Set<Id> applicationIds) {
        attachAsync(new List<Id>(applicationIds));
    }

    @future(callout=true)
    private static void attachAsync(List<Id> applicationIds) {
        // Which apps already have files? (idempotency — don't double-link.)
        Set<Id> alreadyLinked = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :applicationIds
        ]) {
            alreadyLinked.add(cdl.LinkedEntityId);
        }

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id appId : applicationIds) {
            if (alreadyLinked.contains(appId)) continue;
            links.add(new ContentDocumentLink(
                ContentDocumentId = GOLDEN_PASSPORT_DOC,
                LinkedEntityId = appId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
            links.add(new ContentDocumentLink(
                ContentDocumentId = GOLDEN_POWERBILL_DOC,
                LinkedEntityId = appId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }
        if (links.isEmpty()) return;
        Database.insert(links, false); // best-effort; ignore per-row dupes
    }
}
