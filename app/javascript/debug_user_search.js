// Debug script for user search autocomplete
console.log('🔍 Debug User Search - Script loaded');

document.addEventListener('DOMContentLoaded', function() {
  console.log('🔍 DOM loaded, checking elements...');
  
  const userSearchInput = document.getElementById('user-search-input');
  const userIdField = document.getElementById('movement_user_id');
  
  console.log('🔍 User search input:', userSearchInput);
  console.log('🔍 User ID field:', userIdField);
  
  if (userSearchInput) {
    console.log('✅ User search input found');
    
    // Test input events
    userSearchInput.addEventListener('input', function(e) {
      console.log('🔍 Input event triggered:', e.target.value);
    });
    
    userSearchInput.addEventListener('focus', function() {
      console.log('🔍 Focus event triggered');
    });
    
    // Test API endpoint manually
    window.testUserSearch = async function(query = '') {
      console.log('🔍 Testing API endpoint with query:', query);
      
      try {
        const url = `/movements/search_users${query ? `?q=${encodeURIComponent(query)}` : ''}`;
        console.log('🔍 Fetching:', url);
        
        const response = await fetch(url, {
          headers: {
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          }
        });
        
        console.log('🔍 Response status:', response.status);
        console.log('🔍 Response headers:', response.headers);
        
        const data = await response.json();
        console.log('🔍 Response data:', data);
        
        return data;
      } catch (error) {
        console.error('❌ API test error:', error);
        return { error: error.message };
      }
    };
    
    console.log('🔍 Test function available: window.testUserSearch("nome")');
  } else {
    console.error('❌ User search input not found');
  }
  
  if (userIdField) {
    console.log('✅ User ID field found');
  } else {
    console.error('❌ User ID field not found');
  }
  
  // Check if UserSearchAutocomplete class is available
  if (window.UserSearchAutocomplete) {
    console.log('✅ UserSearchAutocomplete class available');
  } else {
    console.error('❌ UserSearchAutocomplete class not available');
  }
});