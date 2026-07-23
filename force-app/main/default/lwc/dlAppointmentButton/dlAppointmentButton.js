import { LightningElement, api } from 'lwc';

/**
 * In-conversation "Book Appointment" button for the Drivers License Agent.
 *
 * Rendered via the DL_AppointmentLink custom Lightning type. The CLT payload
 * ({ url, label }) is injected on `value`. Delivering the link as a component
 * (rather than agent text) avoids the messaging Trust Layer's URL redaction.
 */
export default class DlAppointmentButton extends LightningElement {
    // The CLT value is injected here by the conversation renderer.
    @api value;

    get url() {
        return this.value && this.value.url ? this.value.url : '/dmv/appointment';
    }

    get label() {
        return this.value && this.value.label ? this.value.label : 'Book Appointment';
    }

    handleClick() {
        // Open the appointment page in the top-level window (break out of the
        // chat iframe) so the user lands on the real page, not inside the widget.
        window.open(this.url, '_blank');
    }
}
