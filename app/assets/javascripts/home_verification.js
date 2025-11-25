/**
 * VeriTrust Home Page - Verification & Identity Features
 * Content Verification, DID Generation, Axiam Integration, Signature Creation
 */

$(document).ready(function() {
    
    // ========================================================================
    // State Management
    // ========================================================================
    let verifyMode = 'text';
    let axiamState = { state: 'idle', subject: null, token: null };
    let userDID = localStorage.getItem('veritrust_did') || '';
    let userHandle = localStorage.getItem('veritrust_handle') || '@your.handle';
    let pubKeyJwk = null;
    let privKeyJwk = null;

    // Load saved keys
    const savedPubKey = localStorage.getItem('veritrust_pub');
    const savedPrivKey = localStorage.getItem('veritrust_priv');
    if (savedPubKey) pubKeyJwk = JSON.parse(savedPubKey);
    if (savedPrivKey) privKeyJwk = JSON.parse(savedPrivKey);

    // Initialize UI
    $('#user-handle').text(userHandle);
    if (userDID) {
        $('#did-display').text(userDID);
        $('#copy-did').show();
        $('#create-did').text('Regenerate Keys');
    }
    if (pubKeyJwk) {
        $('#pub-key-display').text(JSON.stringify(pubKeyJwk, null, 2));
        $('#copy-pubkey').show();
    }

    // Use utility functions from veritrust.js
    const { sleep, subtleSha256Hex, b64u } = window.VeriTrust || {};
    
    // Fallback if veritrust.js not loaded
    if (!sleep || !subtleSha256Hex || !b64u) {
        console.error('VeriTrust utilities not loaded!');
        return;
    }

    // ========================================================================
    // Mock API
    // ========================================================================
    const mockAPI = {
        verify: async function(payload) {
            await sleep(700);
            let aiLikelihood = 0.33;
            let provenance = { hasSignature: false, scheme: null, signer: null };
            let ownership = { verified: false, did: null, handle: null };

            if (payload.type === 'text') {
                const text = payload.content || '';
                const low = text.toLowerCase();
                const len = Math.min(0.4, Math.max(0, (text.length - 800) / 4000));
                const hits = [/as an ai/, /large language model/, /neural network/]
                    .reduce((n, re) => n + (re.test(low) ? 1 : 0), 0);
                aiLikelihood = Math.min(0.95, 0.25 + len + hits * 0.18);
            }

            const fingerprint = await subtleSha256Hex(
                payload.type === 'text' ? payload.content :
                payload.type === 'url' ? payload.url :
                (payload.file ? payload.file.name : 'file') + (payload.file ? payload.file.size : 0)
            );

            return {
                ok: true,
                data: {
                    aiLikelihood,
                    fingerprint,
                    provenance,
                    ownership,
                    ownerCandidates: [
                        { handle: '@creator_verified', score: 0.91 },
                        { handle: '@news_org', score: 0.73 }
                    ],
                    modelHints: ['GPT-4', 'Claude', 'Gemini']
                }
            };
        },

        Education: async function() {
            await sleep(250);
            return {
                ok: true,
                data: [
                    { 
                        title: 'Provenance Architecture', 
                        date: '2024-11-15', 
                        authors: 'VeriTrust Labs', 
                        url: '#', 
                        summary: 'Combine C2PA, watermarking, and identity attestations.' 
                    },
                    { 
                        title: 'AI Detection Methods', 
                        date: '2024-10-22', 
                        authors: 'Research Team', 
                        url: '#', 
                        summary: 'Watermark detection and model forensics.' 
                    }
                ]
            };
        },

        contact: async function() {
            await sleep(450);
            return { ok: true };
        }
    };

    // ========================================================================
    // Verification Mode Switching
    // ========================================================================
    $('.mode-btn').click(function() {
        const mode = $(this).data('mode');
        verifyMode = mode;
        $('.verify-mode').hide();
        $(`#${mode}-mode`).show();
        $('.mode-btn').removeClass('btn-primary').addClass('btn-secondary');
        $(this).addClass('btn-primary').removeClass('btn-secondary');
        $('#file-info').hide();
    });

    $('#verify-file').change(function() {
        const file = this.files[0];
        if (file) {
            $('#file-info').text(`${file.name} · ${(file.size / 1024).toFixed(1)} KB`).show();
        } else {
            $('#file-info').hide();
        }
    });

    // ========================================================================
    // Run Verification
    // ========================================================================
    $('#run-verify').click(async function() {
        $('#verify-error').hide();
        const btn = $(this);
        btn.prop('disabled', true).text('Verifying...');

        try {
            let payload;
            if (verifyMode === 'text') {
                const text = $('#verify-text').val().trim();
                if (!text) throw new Error('Please enter some text');
                payload = { type: 'text', content: text };
            } else if (verifyMode === 'url') {
                const url = $('#verify-url').val().trim();
                if (!url) throw new Error('Please enter a URL');
                payload = { type: 'url', url };
            } else if (verifyMode === 'file') {
                const file = $('#verify-file')[0].files[0];
                if (!file) throw new Error('Please select a file');
                payload = { type: 'file', file: { name: file.name, size: file.size, type: file.type } };
            }

            const result = await mockAPI.verify(payload);
            if (!result.ok) throw new Error('Verification failed');
            
            const pct = Math.round((result.data.aiLikelihood || 0) * 100);
            const topOwner = result.data.ownerCandidates.slice().sort((a, b) => b.score - a.score)[0];

            let html = `
                <div class="card p-4 space-y-4">
                    <div class="flex items-center justify-between">
                        <div class="font-medium">AI Likelihood</div>
                        <div class="text-2xl font-bold" style="color: var(--ibm-blue-60)">${pct}%</div>
                    </div>
                    <div class="w-full">
                        <div class="w-full h-3 rounded-full" style="background: var(--border-color)">
                            <div class="gauge-fill rounded-full" style="width: ${pct}%"></div>
                        </div>
                        <div class="text-xs mt-1" style="color: var(--text-secondary)">
                            Confidence: ${pct > 70 ? 'High' : pct > 40 ? 'Medium' : 'Low'}
                        </div>
                    </div>
                    <div class="grid grid-cols-1 gap-3">
                        <div class="info-section">
                            <div class="text-xs uppercase tracking-wide mb-1" style="color: var(--text-secondary)">Fingerprint</div>
                            <div class="font-mono text-xs break-all">${result.data.fingerprint}</div>
                        </div>
                        <div class="info-section">
                            <div class="text-xs uppercase tracking-wide mb-1" style="color: var(--text-secondary)">Provenance</div>
                            <div class="text-sm">✗ No signature found</div>
                        </div>
                        <div class="info-section">
                            <div class="text-xs uppercase tracking-wide mb-1" style="color: var(--text-secondary)">Top Owner Match</div>
                            <div class="text-sm">${topOwner.handle} (${Math.round(topOwner.score * 100)}% confidence)</div>
                        </div>
                    </div>
                </div>
            `;

            $('#verify-results-container').html(html);
        } catch (e) {
            $('#verify-error').text(e.message || 'Something went wrong').show();
        } finally {
            btn.prop('disabled', false).text('Run Verification');
        }
    });

    // ========================================================================
    // Digital ID - Handle Edit
    // ========================================================================
    $('#edit-handle').click(function() {
        const newHandle = prompt('Enter your handle:', userHandle);
        if (newHandle && newHandle.trim()) {
            userHandle = newHandle.trim();
            localStorage.setItem('veritrust_handle', userHandle);
            $('#user-handle').text(userHandle);
        }
    });

    // ========================================================================
    // Digital ID - Axiam Face Sign-In
    // ========================================================================
    $('#start-axiam').click(async function() {
        try {
            $('#identity-status').text('Starting Axiam face sign-in…').show();
            await sleep(1200);
            const subject = 'axiam:sub:' + Math.random().toString(36).slice(2, 10);
            axiamState = { state: 'verified', subject, token: 'mock.jwt' };
            $('#axiam-container').html(`
                <div style="color: #24a46d; font-weight: 500;">✓ Face verified successfully</div>
                <div class="text-sm mt-1" style="color: var(--text-secondary)">Subject: ${subject}</div>
            `);
            $('#identity-status').text('Axiam verification successful.').show();
            $('#axiam-badge').text('Axiam Verified').css({ color: '#24a46d', borderColor: '#24a46d' });
        } catch (e) {
            $('#axiam-badge').text('Axiam Error').css({ color: '#da1e28', borderColor: '#da1e28' });
        }
    });

    // ========================================================================
    // Digital ID - Create DID
    // ========================================================================
    $('#create-did').click(async function() {
        try {
            $('#identity-status').text('Generating keys…').show();
            
            const keyPair = await crypto.subtle.generateKey(
                { name: 'ECDSA', namedCurve: 'P-256' }, 
                true, 
                ['sign', 'verify']
            );
            const pub = await crypto.subtle.exportKey('jwk', keyPair.publicKey);
            const priv = await crypto.subtle.exportKey('jwk', keyPair.privateKey);
            
            const thumb = (await subtleSha256Hex(JSON.stringify(pub))).slice(0, 16);
            const newDid = `did:vt:${thumb}`;
            
            userDID = newDid;
            pubKeyJwk = pub;
            privKeyJwk = priv;
            
            localStorage.setItem('veritrust_did', newDid);
            localStorage.setItem('veritrust_priv', JSON.stringify(priv));
            localStorage.setItem('veritrust_pub', JSON.stringify(pub));
            
            const registry = JSON.parse(localStorage.getItem('veritrust_registry') || '{}');
            registry[newDid] = { 
                publicKeyJwk: pub, 
                handle: userHandle, 
                axiamSubject: axiamState.subject || null 
            };
            localStorage.setItem('veritrust_registry', JSON.stringify(registry));
            
            $('#did-display').text(newDid);
            $('#copy-did').show();
            $('#create-did').text('Regenerate Keys');
            $('#pub-key-display').text(JSON.stringify(pub, null, 2));
            $('#copy-pubkey').show();
            $('#identity-status').text('Keys created. DID ready.').show();
        } catch (e) {
            $('#identity-status').text('Error creating DID: ' + e.message).show();
        }
    });

    // ========================================================================
    // Digital ID - Copy Actions
    // ========================================================================
    $('#copy-did').click(function() {
        navigator.clipboard.writeText(userDID);
        $('#identity-status').text('DID copied to clipboard').show();
    });

    $('#copy-pubkey').click(function() {
        navigator.clipboard.writeText(JSON.stringify(pubKeyJwk));
        $('#identity-status').text('Public key copied to clipboard').show();
    });

    // ========================================================================
    // Digital ID - Generate Signature Tag
    // ========================================================================
    $('#gen-signature').click(async function() {
        try {
            if (!privKeyJwk) {
                $('#identity-status').text('No private key found. Create DID first.').show();
                return;
            }
            
            const fingerprint = await subtleSha256Hex(userHandle + (axiamState.subject || 'anonymous'));
            const pk = await crypto.subtle.importKey(
                'jwk', 
                privKeyJwk, 
                { name: 'ECDSA', namedCurve: 'P-256' }, 
                true, 
                ['sign']
            );
            const msg = new TextEncoder().encode(fingerprint);
            const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, pk, msg);
            const tag = `[VT1:${userDID}:${b64u.encode(new Uint8Array(sig))}]`;
            
            $('#signature-tag').text(tag);
            $('#signature-tag-display').show();
            $('#copy-signature').show();
        } catch (e) {
            $('#identity-status').text('Error generating signature: ' + e.message).show();
        }
    });

    $('#copy-signature').click(function() {
        navigator.clipboard.writeText($('#signature-tag').text());
        $('#identity-status').text('Signature tag copied to clipboard').show();
    });

    // ========================================================================
    // Education Tab - Load Papers
    // ========================================================================
    async function loadEducation() {
        try {
            $('#Education-list').html('<div>Loading…</div>');
            const result = await mockAPI.Education();
            const html = `<div class="grid md:grid-cols-2 gap-4">${result.data.map(p => `
                <div class="card p-4">
                    <h4 class="font-semibold mb-1">${p.title}</h4>
                    <div class="text-xs mb-2" style="color: var(--text-secondary)">${p.authors} · ${p.date}</div>
                    <p class="text-sm mb-2" style="color: var(--text-secondary)">${p.summary}</p>
                    <a href="${p.url}" class="text-sm underline" style="color: var(--ibm-blue-60)">Read more →</a>
                </div>
            `).join('')}</div>`;
            $('#Education-list').html(html);
        } catch (e) {
            $('#Education-list').html(`<div style="color: #da1e28">${e.message}</div>`);
        }
    }

    // ========================================================================
    // Contact Form
    // ========================================================================
    $('#contact-form').submit(async function(e) {
        e.preventDefault();
        const btn = $('#contact-submit');
        btn.prop('disabled', true).text('Sending…');
        $('#contact-error, #contact-success').hide();
        
        try {
            const result = await mockAPI.contact();
            if (!result.ok) throw new Error('Failed to send');
            $('#contact-success').show();
            $('#contact-name, #contact-email, #contact-message').val('');
        } catch (e) {
            $('#contact-error').text(e.message).show();
        } finally {
            btn.prop('disabled', false).text('Send message');
        }
    });

    // ========================================================================
    // Initialize on Load
    // ========================================================================
    // Load education content if tab exists
    if ($('#Education-list').length) {
        loadEducation();
    }
    
});
