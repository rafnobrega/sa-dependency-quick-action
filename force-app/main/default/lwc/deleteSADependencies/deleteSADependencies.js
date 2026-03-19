import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import deleteDependencies from '@salesforce/apex/SADependencyController.deleteDependencies';

export default class DeleteSADependencies extends LightningElement {
    @api recordId;

    isProcessing = false;
    isComplete = false;
    resultMessage = '';
    isError = false;
    includeWoliSAs = false;

    handleToggleWoli(event) {
        this.includeWoliSAs = event.target.checked;
    }

    handleDelete() {
        this.isProcessing = true;

        deleteDependencies({ workOrderId: this.recordId, includeWoliSAs: this.includeWoliSAs })
            .then(result => {
                this.resultMessage = result;
                this.isError = false;
                this.isComplete = true;
                this.isProcessing = false;
            })
            .catch(error => {
                this.resultMessage = error.body ? error.body.message : 'An unexpected error occurred.';
                this.isError = true;
                this.isComplete = true;
                this.isProcessing = false;
            });
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    get showConfirmation() {
        return !this.isProcessing && !this.isComplete;
    }

    get resultClass() {
        return this.isError ? 'result-message result-error' : 'result-message result-success';
    }

    get resultIcon() {
        return this.isError ? 'utility:error' : 'utility:success';
    }

    get resultVariant() {
        return this.isError ? 'error' : 'success';
    }
}
