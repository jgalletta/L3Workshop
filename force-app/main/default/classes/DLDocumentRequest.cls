/**
 * Invocable action for the Drivers License Agent.
 *
 * Returns the payload for the DL_DocUpload custom Lightning type, which renders
 * an in-conversation widget prompting the user to upload their identity and
 * proof-of-address documents. Files are attached to the Application record that
 * anchors the conversation, so no Contact is required up front.
 */
public with sharing class DLDocumentRequest {

    public class Request {
        @InvocableVariable(
            label='Application Id'
            description='The Application the uploaded documents will be attached to.'
            required=true
        )
        public String applicationId;
    }

    // Shape matches the DL_DocUpload CLT schema (applicationId, instructions).
    public class UploadWidget {
        @InvocableVariable(label='Application Id')
        public String applicationId;
        @InvocableVariable(label='Instructions')
        public String instructions;
    }

    public class Result {
        @InvocableVariable(label='Upload Widget' description='Payload rendered by the DL_DocUpload custom Lightning type.')
        public UploadWidget uploadWidget;
    }

    @InvocableMethod(
        label='Request Identity Documents'
        description='Returns the in-conversation document upload widget for identity and proof of address.'
    )
    public static List<Result> request(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            UploadWidget w = new UploadWidget();
            w.applicationId = req.applicationId;
            w.instructions = 'Please upload your form of identification and your proof of address as PNG files.';
            Result r = new Result();
            r.uploadWidget = w;
            results.add(r);
        }
        return results;
    }
}
