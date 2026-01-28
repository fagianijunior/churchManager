// Amount Handler Component for Movement Forms
class AmountHandler {
  constructor(amountInput, kindOfSelect, formContainer) {
    this.amountInput = amountInput;
    this.kindOfSelect = kindOfSelect;
    this.formContainer = formContainer;
    this.originalValue = '';
    
    this.init();
  }
  
  init() {
    this.bindEvents();
    this.updateUIForCurrentType();
    this.formatAmountInput();
  }
  
  bindEvents() {
    // Monitor movement type changes
    this.kindOfSelect.addEventListener('change', () => {
      this.handleTypeChange();
    });
    
    // Format amount as user types
    this.amountInput.addEventListener('input', (e) => {
      this.formatAmountInput();
    });
    
    // Store original value on focus
    this.amountInput.addEventListener('focus', () => {
      this.originalValue = this.amountInput.value;
    });
    
    // Validate on blur
    this.amountInput.addEventListener('blur', () => {
      this.validateAmount();
    });
  }
  
  handleTypeChange() {
    this.updateUIForCurrentType();
    this.updateAmountDisplay();
  }
  
  updateUIForCurrentType() {
    const selectedType = this.kindOfSelect.value;
    
    // Remove existing type classes
    this.formContainer.classList.remove('movement-income', 'movement-expense');
    
    // Add appropriate class based on type
    if (selectedType === 'entrada') {
      this.formContainer.classList.add('movement-income');
      this.updateAmountLabel('Valor da Entrada', 'text-green-600');
      this.updateAmountPlaceholder('Ex: 100.00');
    } else if (selectedType === 'saida') {
      this.formContainer.classList.add('movement-expense');
      this.updateAmountLabel('Valor da Saída', 'text-red-600');
      this.updateAmountPlaceholder('Ex: 50.00');
    } else {
      this.updateAmountLabel('Valor', 'text-gray-600');
      this.updateAmountPlaceholder('0.00');
    }
  }
  
  updateAmountLabel(text, colorClass) {
    const label = this.formContainer.querySelector('label[for="movement_amount"]');
    if (label) {
      label.textContent = text;
      label.className = `block text-sm font-medium ${colorClass}`;
    }
  }
  
  updateAmountPlaceholder(placeholder) {
    this.amountInput.placeholder = placeholder;
  }
  
  updateAmountDisplay() {
    // This ensures the display shows positive values regardless of type
    const currentValue = this.amountInput.value;
    if (currentValue) {
      const numericValue = parseFloat(currentValue.replace(/[^\d.,]/g, '').replace(',', '.'));
      if (!isNaN(numericValue)) {
        this.amountInput.value = Math.abs(numericValue).toFixed(2);
      }
    }
  }
  
  formatAmountInput() {
    let value = this.amountInput.value;
    
    // Remove non-numeric characters except decimal separators
    value = value.replace(/[^\d.,]/g, '');
    
    // Replace comma with dot for decimal
    value = value.replace(',', '.');
    
    // Ensure only one decimal point
    const parts = value.split('.');
    if (parts.length > 2) {
      value = parts[0] + '.' + parts.slice(1).join('');
    }
    
    // Limit decimal places to 2
    if (parts.length === 2 && parts[1].length > 2) {
      value = parts[0] + '.' + parts[1].substring(0, 2);
    }
    
    this.amountInput.value = value;
    
    // Add visual formatting for display
    this.addCurrencyFormatting();
  }
  
  addCurrencyFormatting() {
    const value = this.amountInput.value;
    if (value && !isNaN(parseFloat(value))) {
      // Add currency symbol in a visual indicator
      this.showCurrencyIndicator();
    } else {
      this.hideCurrencyIndicator();
    }
  }
  
  showCurrencyIndicator() {
    let indicator = this.amountInput.parentElement.querySelector('.currency-indicator');
    
    if (!indicator) {
      indicator = document.createElement('span');
      indicator.className = 'currency-indicator';
      indicator.textContent = 'R$';
      indicator.style.cssText = `
        position: absolute;
        left: 12px;
        top: 50%;
        transform: translateY(-50%);
        color: #6b7280;
        font-weight: 500;
        pointer-events: none;
        z-index: 1;
      `;
      
      this.amountInput.parentElement.style.position = 'relative';
      this.amountInput.parentElement.appendChild(indicator);
      this.amountInput.style.paddingLeft = '40px';
    }
  }
  
  hideCurrencyIndicator() {
    const indicator = this.amountInput.parentElement.querySelector('.currency-indicator');
    if (indicator) {
      indicator.remove();
      this.amountInput.style.paddingLeft = '';
    }
  }
  
  validateAmount() {
    const value = this.amountInput.value;
    const numericValue = parseFloat(value);
    
    // Clear previous validation messages
    this.clearValidationMessage();
    
    if (value && isNaN(numericValue)) {
      this.showValidationMessage('Por favor, insira um valor numérico válido', 'error');
      return false;
    }
    
    if (numericValue < 0) {
      this.showValidationMessage('O valor deve ser positivo (o sinal será aplicado automaticamente)', 'warning');
      this.amountInput.value = Math.abs(numericValue).toFixed(2);
    }
    
    if (numericValue === 0) {
      this.showValidationMessage('O valor deve ser maior que zero', 'error');
      return false;
    }
    
    return true;
  }
  
  showValidationMessage(message, type) {
    let messageElement = this.amountInput.parentElement.querySelector('.amount-validation-message');
    
    if (!messageElement) {
      messageElement = document.createElement('div');
      messageElement.className = 'amount-validation-message';
      this.amountInput.parentElement.appendChild(messageElement);
    }
    
    messageElement.textContent = message;
    messageElement.className = `amount-validation-message ${type}`;
    
    const styles = {
      error: 'color: #dc2626; background-color: #fef2f2; border-color: #fecaca;',
      warning: 'color: #d97706; background-color: #fffbeb; border-color: #fed7aa;',
      success: 'color: #059669; background-color: #ecfdf5; border-color: #a7f3d0;'
    };
    
    messageElement.style.cssText = `
      ${styles[type]}
      padding: 8px 12px;
      border: 1px solid;
      border-radius: 0.375rem;
      font-size: 0.875rem;
      margin-top: 4px;
    `;
  }
  
  clearValidationMessage() {
    const messageElement = this.amountInput.parentElement.querySelector('.amount-validation-message');
    if (messageElement) {
      messageElement.remove();
    }
  }
  
  // Method to get the processed amount for form submission
  getProcessedAmount() {
    const value = parseFloat(this.amountInput.value);
    const type = this.kindOfSelect.value;
    
    if (isNaN(value)) return 0;
    
    // Always return positive value - server will handle sign based on type
    return Math.abs(value);
  }
}

// Initialize amount handler when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
  const amountInput = document.getElementById('movement_amount');
  const kindOfSelect = document.getElementById('movement_kind_of');
  const formContainer = document.querySelector('.movement-form') || document.body;
  
  if (amountInput && kindOfSelect) {
    new AmountHandler(amountInput, kindOfSelect, formContainer);
  }
});

// Export for potential external use
window.AmountHandler = AmountHandler;