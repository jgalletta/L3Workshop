/**
 * Invocable action for the Drivers License Agent.
 *
 * Returns the payload for the DL_AppointmentLink custom Lightning type, which
 * renders a single "Book Appointment" button in the conversation. The button
 * opens the DMV appointment scheduling page.
 *
 * Why a component instead of a text link: the messaging Trust Layer redacts
 * full URLs in agent-generated text ("URL_Redacted"). Delivering the link as a
 * component payload bypasses that, so the button always works.
 */
public with sharing class DLAppointmentLink {

    // The DMV appointment scheduling page (relative path on the same site).
    private static final String APPOINTMENT_URL = '/dmv/appointment';

    public class Request {
        @InvocableVariable(
            label='Label'
            description='Optional button label. Defaults to "Book Appointment".'
        )
        public String label;
    }

    // Shape matches the DL_AppointmentLink CLT schema (url, label).
    public class LinkWidget {
        @InvocableVariable(label='URL')
        public String url;
        @InvocableVariable(label='Label')
        public String label;
    }

    public class Result {
        @InvocableVariable(label='Link Widget' description='Payload rendered by the DL_AppointmentLink custom Lightning type.')
        public LinkWidget linkWidget;
    }

    @InvocableMethod(
        label='Show Appointment Booking Button'
        description='Returns the in-conversation button that opens the DMV appointment scheduling page.'
    )
    public static List<Result> show(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            LinkWidget w = new LinkWidget();
            w.url = APPOINTMENT_URL;
            w.label = String.isNotBlank(req.label) ? req.label : 'Book Appointment';
            Result r = new Result();
            r.linkWidget = w;
            results.add(r);
        }
        return results;
    }
}
