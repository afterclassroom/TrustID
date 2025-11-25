// Global flag để track initialization status
window.AXIAM_CLIENT_INITIALIZED = false;

// Enhanced lazy init function - chỉ khởi tạo khi cần
window.initAxiamClientIfNeeded = async function() {
  if (window.AXIAM_CLIENT_INITIALIZED && window.App && window.App.axiamClient) {
    return true;
  }
  
  if (!window.App) {
    window.App = {};
  }
  
  if (!window.SITE_CREDENTIALS) {
    console.error('❌ Thiếu SITE_CREDENTIALS. Vui lòng set trong application.html.erb');
    return false;
  }
  
  // Validate credentials (client only needs public info)
  const { channel_prefix, server_url } = window.SITE_CREDENTIALS;
  if (!channel_prefix || !server_url) {
    console.error('❌ SITE_CREDENTIALS không đầy đủ (client cần channel_prefix và server_url):', window.SITE_CREDENTIALS);
    console.error('❌ Vui lòng kiểm tra ENV variables: CHANNEL_PREFIX, SERVER_URL (server-side)');
    return false;
  }
  
  try {
    // Tạo instance mới với dynamic server URL từ ENV
    // NOTE: Redis credentials MUST NOT be exposed to the browser.
    // The client only needs the channel prefix and the ActionCable server URL.
    window.App.axiamClient = new AxiamActionCableClient({
      siteCredentials: {
        channel_prefix
      },
      serverUrl: server_url
    });
    
    // Connect
    await window.App.axiamClient.connect();
    
    // Set flag để không init lại
    window.AXIAM_CLIENT_INITIALIZED = true;
    
    return true;
    
  } catch (error) {
    console.error('❌ Lỗi khởi tạo AxiamActionCableClient:', error);
    return false;
  }
};

// Enhanced subscribeFacialSignOn với lazy initialization
window.subscribeFacialSignOn = function(verificationToken) {
  async function attemptSubscribe() {
    // Lazy init AxiamActionCableClient nếu chưa có
    if (!window.AXIAM_CLIENT_INITIALIZED || !window.App || !window.App.axiamClient) {
      const initSuccess = await window.initAxiamClientIfNeeded();
      if (!initSuccess) {
        console.error('❌ Không thể khởi tạo AxiamActionCableClient');
        setTimeout(attemptSubscribe, 2000);
        return;
      }
    }
    
    // Kiểm tra connection status và tự động connect nếu cần
    if (!window.App.axiamClient.isConnected()) {
      try {
        await window.App.axiamClient.connect();
        performSubscription();
      } catch (error) {
        console.error('❌ Lỗi kết nối:', error);
        setTimeout(attemptSubscribe, 1000);
      }
      return;
    }
    
    // Nếu đã kết nối rồi thì subscribe luôn
    performSubscription();
  }
  
  function performSubscription() {
    try {
      // Sử dụng helper method của AxiamActionCableClient
      const subscription = window.App.axiamClient.subscribeFacialSignOn(verificationToken, {
        onConnected: () => {
          showStatus('Đang chờ xác thực khuôn mặt...', 'info');
        },
        
        onDisconnected: () => {
          showStatus('Mất kết nối. Đang thử kết nối lại...', 'warning');
        },
        
        onMessage: (data) => {
          handleFacialSignOnMessage(data);
        }
      });
      
      // Lưu subscription để cleanup sau này
      window.App.facialSignOnSubscription = subscription;
      
    } catch (error) {
      console.error('❌ Lỗi khi tạo subscription:', error);
      showStatus('Lỗi kết nối. Vui lòng thử lại.', 'error');
      
      // Thử lại sau 2 giây
      setTimeout(attemptSubscribe, 2000);
    }
  }
  
  // Xử lý tin nhắn facial sign-on
  function handleFacialSignOnMessage(data) {
    switch (data.status) {
      case 'verified':
      case 'success':
        handleSuccessAuth(data);
        break;
        
      case 'failed':
      case 'error':
        handleFailedAuth(data);
        break;
        
      case 'pending':
        handlePendingAuth(data);
        break;
        
      case 'timeout':
        handleTimeoutAuth(data);
        break;
        
      case 'processing':
        handleProcessingAuth(data);
        break;
        
      default:
        handleGenericAuth(data);
    }
  }
  
  // Xử lý xác thực thành công - chỉ cần client_id
  function handleSuccessAuth(data) {
    showStatus('Xác thực thành công! Đang đăng nhập...', 'success');
    
    if (data.client_id) {
      performAutoLogin(data.client_id);
    } else if (data.redirect_url) {
      setTimeout(() => {
        window.location.href = data.redirect_url;
      }, 1500);
    } else {
      console.error('❌ Không có client_id hoặc redirect_url từ Axiam');
      showStatus('Lỗi xác thực. Vui lòng thử lại.', 'error');
      setTimeout(() => {
        window.location.href = '/facial_sign_on/login';
      }, 2000);
    }
  }
  
  // Xử lý xác thực thất bại
  function handleFailedAuth(data) {
    const errorMessage = data.message || 'Xác thực khuôn mặt thất bại. Vui lòng thử lại.';
    showStatus(errorMessage, 'error');
  }
  
  // Xử lý trạng thái pending
  function handlePendingAuth(data) {
    const message = data.message || 'Đang chờ xác thực khuôn mặt...';
    showStatus(message, 'info');
  }
  
  // Xử lý timeout
  function handleTimeoutAuth(data) {
    const timeoutMessage = data.message || 'Hết thời gian xác thực. Vui lòng thử lại.';
    showStatus(timeoutMessage, 'warning');
  }
  
  // Xử lý trạng thái processing
  function handleProcessingAuth(data) {
    const message = data.message || 'Đang xử lý dữ liệu xác thực...';
    showStatus(message, 'info');
  }
  
  // Xử lý các trạng thái khác
  function handleGenericAuth(data) {
    if (data.message) {
      showStatus(data.message, 'info');
    }
  }
  
  // Enhanced auto-login với chỉ client_id
  function performAutoLogin(clientId) {
    if (!clientId) {
      console.error('❌ Không có client_id để thực hiện auto-login');
      showStatus('Thiếu thông tin xác thực. Đang chuyển hướng...', 'warning');
      setTimeout(() => {
        window.location.href = '/facial_sign_on/login';
      }, 2000);
      return;
    }
    
    // AJAX login with client_id
    fetch('/facial_sign_on/verified_login', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ axiam_uid: clientId })
    })
    .then(res => res.json())
    .then(json => {
        if(json.success) {
            showStatus('Đăng nhập thành công! Đang chuyển hướng...', 'success');
            window.location.href = '/dashboard';
        } else {
            console.error('❌ Auto-login failed:', json.error);
            showStatus('Đăng nhập thất bại: ' + (json.error || 'Unknown error'), 'error');
        }
    })
    .catch(error => {
        console.error('❌ Network error during auto-login:', error);
        showStatus('Lỗi kết nối. Vui lòng thử lại.', 'error');
    });
  }
  
  // Hiển thị status message
  function showStatus(message, type = 'info') {
    // Kiểm tra xem có custom notification function không
    if (typeof window.showNotification === 'function') {
      window.showNotification(message, type);
      return;
    }
    
    // Fallback: console hoặc alert cho error
    if (type === 'error') {
      alert(message);
    }
  }
  
  // Bắt đầu quá trình subscribe
  attemptSubscribe();
};

// Global cleanup function để tránh auto-init
window.cleanupAxiamClient = function() {
  if (window.AXIAM_CLIENT_INITIALIZED && window.App && window.App.axiamClient) {
    try {
      window.App.axiamClient.disconnect();
      window.App.axiamClient = null;
      window.App.facialSignOnSubscription = null;
      window.AXIAM_CLIENT_INITIALIZED = false;
    } catch (error) {
      console.warn('Warning khi cleanup:', error);
    }
  }
};

// Auto-cleanup khi navigate away từ facial sign-on pages
window.addEventListener('beforeunload', function() {
  // Chỉ cleanup nếu đang rời khỏi facial sign-on flow
  const currentPath = window.location.pathname;
  if (!currentPath.includes('/facial_sign_on/')) {
    window.cleanupAxiamClient();
  }
});

// Event listeners - KHÔNG auto-init
document.addEventListener('DOMContentLoaded', function() {
  // KHÔNG auto-init AxiamActionCableClient ở đây
  // Chỉ init khi user enter email và cần facial authentication
});

/*
=== HƯỚNG DẪN SỬ DỤNG ===

1. Sử dụng cơ bản:
   subscribeFacialSignOn('user_token_123');

2. Sử dụng nâng cao với options:
   subscribeFacialSignOnEnhanced('user_token_123', {
     retryAttempts: 3,
     retryDelay: 1500,
     autoCleanup: true
   });

3. Kiểm tra kết nối:
   checkAxiamConnection();

4. Kết nối lại thủ công:
   reconnectAxiam();

5. Cleanup thủ công:
   cleanupFacialSignOn();

=== YÊU CẦU ===
- AxiamActionCableClient phải được khởi tạo trước trong window.App.axiamClient
- Element #verified-login-form và #client_id phải tồn tại cho auto-login
- Có thể tùy chỉnh showNotification function hoặc status elements

=== EVENTS ===
- Lắng nghe 'axiamActionCableReady' để biết khi nào client sẵn sàng
- Auto-cleanup khi beforeunload

*/