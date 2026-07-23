/**
 * Invocable action for the Drivers License Agent.
 *
 * Creates a new Application__c record at the start of the conversation. The
 * Application is the hub that holds everything captured in the chat: uploaded
 * documents, extracted personal details, geocoded address, and (later) the
 * appointment. Returns the new Application Id so the agent can thread it through
 * the rest of the conversation.
 */
public with sharing class DLCreateApplication {

    public class Request {
        @InvocableVariable(
            label='Service Type'
            description='The driver license service the user is applying for, if known.'
        )
        public String serviceType;
    }

    public class Result {
        @InvocableVariable(label='Application Id' description='Id of the newly created Application record.')
        public String applicationId;
        @InvocableVariable(label='Application Number' description='Human-readable application number.')
        public String applicationNumber;
        @InvocableVariable(label='Message' description='Status message.')
        public String message;
    }

    @InvocableMethod(
        label='Create Application'
        description='Creates a new driver license Application record to anchor the conversation.'
    )
    public static List<Result> create(List<Request> requests) {
        List<Application__c> toInsert = new List<Application__c>();
        for (Request req : requests) {
            toInsert.add(new Application__c(
                Status__c = 'Draft',
                Service_Type__c = req.serviceType
            ));
        }
        insert toInsert;

        Map<Id, Application__c> byId = new Map<Id, Application__c>(
            [SELECT Id, Name FROM Application__c WHERE Id IN :toInsert]
        );

        List<Result> results = new List<Result>();
        for (Application__c a : toInsert) {
            Result r = new Result();
            r.applicationId = a.Id;
            Application__c saved = byId.get(a.Id);
            r.applicationNumber = (saved != null) ? saved.Name : null;
            r.message = 'Created application ' + r.applicationNumber + '.';
            results.add(r);
        }
        return results;
    }
}
