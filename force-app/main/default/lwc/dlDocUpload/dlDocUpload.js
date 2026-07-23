import { LightningElement, api, track } from 'lwc';

/**
 * In-conversation document upload widget for the Drivers License Agent.
 *
 * Rendered via the DL_DocUpload custom Lightning type. Lets the user upload
 * two PNG documents (a form of ID and a proof of address). Files are attached
 * to the user's Contact record; the resulting ContentDocument Ids are tracked
 * so a downstream Doc AI step can read them.
 */
export default class DlDocUpload extends LightningElement {
    // The CLT value is injected here by the conversation renderer.
    @api value;

    @track idUploaded = false;
    @track addressUploaded = false;
    @track uploadedDocIds = [];

    acceptedFormats = ['.png'];

    get applicationId() {
        return this.value && this.value.applicationId ? this.value.applicationId : null;
    }

    get instructions() {
        return this.value && this.value.instructions
            ? this.value.instructions
            : 'Please upload your form of identification and your proof of address (PNG files).';
    }

    get bothUploaded() {
        return this.idUploaded && this.addressUploaded;
    }

    handleIdUpload(event) {
        this.captureFiles(event);
        this.idUploaded = true;
    }

    handleAddressUpload(event) {
        this.captureFiles(event);
        this.addressUploaded = true;
    }

    captureFiles(event) {
        const files = event.detail.files || [];
        files.forEach((f) => this.uploadedDocIds.push(f.documentId));
    }
}