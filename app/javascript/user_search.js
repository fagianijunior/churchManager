// User Search Autocomplete Component
class UserSearchAutocomplete {
  constructor(inputElement, hiddenFieldElement) {
    this.input = inputElement;
    this.hiddenField = hiddenFieldElement;
    this.searchTimeout = null;
    this.resultsContainer = null;
    this.selectedIndex = -1;
    this.currentResults = [];
    
    this.init();
  }
  
  init() {
    this.createResultsContainer();
    this.bindEvents();
    this.loadRecentUsers();
  }
  
  createResultsContainer() {
    this.resultsContainer = document.createElement('div');
    this.resultsContainer.className = 'user-search-results';
    this.resultsContainer.style.cssText = `
      position: absolute;
      top: 100%;
      left: 0;
      right: 0;
      background: white;
      border: 1px solid #d1d5db;
      border-top: none;
      border-radius: 0 0 0.375rem 0.375rem;
      max-height: 200px;
      overflow-y: auto;
      z-index: 1000;
      display: none;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    `;
    
    // Make input container relative
    this.input.parentElement.style.position = 'relative';
    this.input.parentElement.appendChild(this.resultsContainer);
  }
  
  bindEvents() {
    // Search on input
    this.input.addEventListener('input', (e) => {
      const query = e.target.value.trim();
      this.debounceSearch(query);
    });
    
    // Handle keyboard navigation
    this.input.addEventListener('keydown', (e) => {
      this.handleKeyNavigation(e);
    });
    
    // Show recent users on focus
    this.input.addEventListener('focus', () => {
      if (this.input.value.trim() === '') {
        this.loadRecentUsers();
      }
    });
    
    // Hide results when clicking outside
    document.addEventListener('click', (e) => {
      if (!this.input.parentElement.contains(e.target)) {
        this.hideResults();
      }
    });
  }
  
  debounceSearch(query) {
    clearTimeout(this.searchTimeout);
    this.searchTimeout = setTimeout(() => {
      this.performSearch(query);
    }, 300);
  }
  
  async performSearch(query) {
    try {
      const response = await fetch(`/movements/search_users?q=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      });
      
      if (!response.ok) {
        throw new Error('Erro na busca');
      }
      
      const data = await response.json();
      
      if (data.success) {
        this.displayResults(data.users, query);
      } else {
        this.showError(data.error || 'Erro ao buscar usuários');
      }
    } catch (error) {
      console.error('Search error:', error);
      this.showError('Erro de conexão. Tente novamente.');
    }
  }
  
  async loadRecentUsers() {
    try {
      const response = await fetch('/movements/search_users', {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      });
      
      if (!response.ok) {
        throw new Error('Erro ao carregar usuários recentes');
      }
      
      const data = await response.json();
      
      if (data.success && data.users.length > 0) {
        this.displayResults(data.users, '', 'Membros utilizados recentemente:');
      }
    } catch (error) {
      console.error('Recent users error:', error);
    }
  }
  
  displayResults(users, query = '', header = '') {
    this.currentResults = users;
    this.selectedIndex = -1;
    
    if (users.length === 0) {
      this.showNoResults(query);
      return;
    }
    
    let html = '';
    
    if (header) {
      html += `<div class="search-header">${header}</div>`;
    }
    
    users.forEach((user, index) => {
      const highlightedName = query ? 
        this.highlightMatch(user.name, query) : 
        user.name;
        
      html += `
        <div class="search-result-item" data-index="${index}" data-user-id="${user.id}">
          <div class="user-name">${highlightedName}</div>
          <div class="user-details">${user.email || ''}</div>
          ${user.is_member ? `<div class="user-member-info">Membro desde ${user.member_since}</div>` : ''}
        </div>
      `;
    });
    
    this.resultsContainer.innerHTML = html;
    this.showResults();
    this.bindResultEvents();
  }
  
  highlightMatch(text, query) {
    if (!query) return text;
    const regex = new RegExp(`(${query})`, 'gi');
    return text.replace(regex, '<strong>$1</strong>');
  }
  
  showNoResults(query) {
    const message = query ? 
      `Nenhum membro encontrado para "${query}"` : 
      'Nenhum membro encontrado';
      
    this.resultsContainer.innerHTML = `
      <div class="no-results">${message}</div>
    `;
    this.showResults();
  }
  
  showError(message) {
    this.resultsContainer.innerHTML = `
      <div class="search-error">${message}</div>
    `;
    this.showResults();
  }
  
  showResults() {
    this.resultsContainer.style.display = 'block';
  }
  
  hideResults() {
    this.resultsContainer.style.display = 'none';
  }
  
  bindResultEvents() {
    const items = this.resultsContainer.querySelectorAll('.search-result-item');
    
    items.forEach((item, index) => {
      item.addEventListener('click', () => {
        this.selectUser(index);
      });
      
      item.addEventListener('mouseenter', () => {
        this.highlightItem(index);
      });
    });
  }
  
  handleKeyNavigation(e) {
    const items = this.resultsContainer.querySelectorAll('.search-result-item');
    
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1);
        this.highlightItem(this.selectedIndex);
        break;
        
      case 'ArrowUp':
        e.preventDefault();
        this.selectedIndex = Math.max(this.selectedIndex - 1, -1);
        this.highlightItem(this.selectedIndex);
        break;
        
      case 'Enter':
        e.preventDefault();
        if (this.selectedIndex >= 0) {
          this.selectUser(this.selectedIndex);
        }
        break;
        
      case 'Escape':
        this.hideResults();
        break;
    }
  }
  
  highlightItem(index) {
    const items = this.resultsContainer.querySelectorAll('.search-result-item');
    
    items.forEach((item, i) => {
      if (i === index) {
        item.classList.add('highlighted');
      } else {
        item.classList.remove('highlighted');
      }
    });
    
    this.selectedIndex = index;
  }
  
  selectUser(index) {
    if (index >= 0 && index < this.currentResults.length) {
      const user = this.currentResults[index];
      
      // Update form fields
      this.input.value = user.name;
      this.hiddenField.value = user.id;
      
      // Trigger change event for any listeners
      this.hiddenField.dispatchEvent(new Event('change', { bubbles: true }));
      
      this.hideResults();
    }
  }
}

// Initialize user search when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
  const userSearchInput = document.getElementById('user-search-input');
  const userIdField = document.getElementById('movement_user_id');
  
  if (userSearchInput && userIdField) {
    new UserSearchAutocomplete(userSearchInput, userIdField);
  }
});

// Export for potential external use
window.UserSearchAutocomplete = UserSearchAutocomplete;