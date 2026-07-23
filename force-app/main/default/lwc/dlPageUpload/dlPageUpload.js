import { LightningElement, track } from 'lwc';
import createApplicationForUpload from '@salesforce/apex/DLPageUploadController.createApplicationForUpload';

/**
 * On-page document upload for the DMV Experience site (placed beside the chat).
 * Creates an Application on load, then lets the user attach their ID and proof
 * of address to it. The agent picks up the files by discovering the most recent
 * unprocessed Application with attachments.
 */
export default class DlPageUpload extends LightningElement {
    @track applicationId;
    @track idUploaded = false;
    @track addressUploaded = false;
    @track error;

    acceptedFormats = ['.png', '.jpg', '.jpeg', '.pdf'];

    async connectedCallback() {
        try {
            this.applicationId = await createApplicationForUpload();
        } catch (e) {
            this.error = 'Could not start your application. Please refresh and try again.';
        }
    }

    get ready() {
        return !!this.applicationId;
    }

    get bothUploaded() {
        return this.idUploaded && this.addressUploaded;
    }

    handleIdUpload() {
        this.idUploaded = true;
    }

    handleAddressUpload() {
        this.addressUploaded = true;
    }
}