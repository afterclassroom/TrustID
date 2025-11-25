/**
 * VeriTrust - Shared JavaScript
 * Navigation, User Dropdowns, Tab Management, Utility Functions
 */

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Sleep utility for async operations
 */
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * SHA-256 hash using SubtleCrypto or fallback
 */
async function subtleSha256Hex(input) {
    if (window.crypto && window.crypto.subtle) {
        const enc = new TextEncoder().encode(input);
        const buf = await window.crypto.subtle.digest('SHA-256', enc);
        return Array.from(new Uint8Array(buf))
            .map(b => b.toString(16).padStart(2, '0'))
            .join('');
    }
    // Fallback simple hash (not cryptographically secure)
    let h = 0;
    for (let i = 0; i < input.length; i++) {
        h = (h * 31 + input.charCodeAt(i)) >>> 0;
    }
    return h.toString(16);
}

/**
 * Base64URL encoding/decoding
 */
const b64u = {
    encode: (buf) => {
        const b = typeof buf === 'string' ? new TextEncoder().encode(buf) : new Uint8Array(buf);
        let str = btoa(String.fromCharCode(...b));
        return str.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    },
    decode: (s) => {
        s = s.replace(/-/g, '+').replace(/_/g, '/');
        while (s.length % 4) s += '=';
        const bin = atob(s);
        const bytes = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
        return bytes;
    }
};

// ============================================================================
// DOM Ready Initialization
// ============================================================================

document.addEventListener('DOMContentLoaded', function() {
    
    // ========================================================================
    // Hamburger Menu Toggle
    // ========================================================================
    const hamburger = document.getElementById('hamburger');
    const mobileMenu = document.getElementById('mobileMenu');
    
    if (hamburger && mobileMenu) {
        hamburger.addEventListener('click', function() {
            mobileMenu.classList.toggle('active');
            this.classList.toggle('active');
        });
    }
    
    // ========================================================================
    // Desktop User Dropdown
    // ========================================================================
    const userMenuDesktop = document.getElementById('user-menu-desktop');
    const userDropdownDesktop = document.getElementById('user-dropdown-desktop');
    
    if (userMenuDesktop && userDropdownDesktop) {
        userMenuDesktop.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            userDropdownDesktop.classList.toggle('active');
        });
        
        // Close dropdown when clicking outside
        document.addEventListener('click', function(e) {
            if (!userDropdownDesktop.contains(e.target)) {
                userDropdownDesktop.classList.remove('active');
            }
        });
    }
    
    // ========================================================================
    // Tab Navigation for VeriTrust
    // ========================================================================
    const tabs = document.querySelectorAll('.nav-tab-vt');
    const tabContents = document.querySelectorAll('.tab-content');
    
    tabs.forEach(tab => {
        tab.addEventListener('click', function() {
            const targetTab = this.getAttribute('data-tab');
            
            // Update active states
            tabs.forEach(t => t.classList.remove('active'));
            this.classList.add('active');
            
            // Show target content
            tabContents.forEach(content => {
                content.classList.remove('active');
            });
            const targetContent = document.getElementById(targetTab + '-tab');
            if (targetContent) {
                targetContent.classList.add('active');
            }
        });
    });
    
});

// Export utilities to window for use in other scripts
if (typeof window !== 'undefined') {
    window.VeriTrust = {
        sleep,
        subtleSha256Hex,
        b64u
    };
}
