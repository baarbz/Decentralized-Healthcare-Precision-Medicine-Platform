;; Provider Verification Contract
;; Validates and stores healthcare provider credentials

(define-data-var admin principal tx-sender)

;; Provider status: 0 = unverified, 1 = verified, 2 = suspended
(define-map providers
  { provider-id: principal }
  {
    name: (string-utf8 100),
    specialty: (string-utf8 100),
    license-number: (string-utf8 50),
    status: uint,
    verification-date: uint
  }
)

;; Verifiers authorized to validate providers
(define-map authorized-verifiers
  { verifier-id: principal }
  { is-authorized: bool }
)

;; Register a new healthcare provider (self-registration)
(define-public (register-provider
                (name (string-utf8 100))
                (specialty (string-utf8 100))
                (license-number (string-utf8 50)))
  (begin
    (asserts! (not (is-provider-registered tx-sender)) (err u1))
    (map-set providers
      { provider-id: tx-sender }
      {
        name: name,
        specialty: specialty,
        license-number: license-number,
        status: u0,
        verification-date: u0
      }
    )
    (ok true)
  )
)

;; Verify a healthcare provider
(define-public (verify-provider (provider-id principal))
  (begin
    (asserts! (is-authorized-verifier tx-sender) (err u2))
    (asserts! (is-provider-registered provider-id) (err u3))
    (let ((provider-data (unwrap! (map-get? providers { provider-id: provider-id }) (err u4))))
      (map-set providers
        { provider-id: provider-id }
        (merge provider-data {
          status: u1,
          verification-date: block-height
        })
      )
      (ok true)
    )
  )
)

;; Suspend a provider
(define-public (suspend-provider (provider-id principal))
  (begin
    (asserts! (is-authorized-verifier tx-sender) (err u2))
    (asserts! (is-provider-registered provider-id) (err u3))
    (let ((provider-data (unwrap! (map-get? providers { provider-id: provider-id }) (err u4))))
      (map-set providers
        { provider-id: provider-id }
        (merge provider-data { status: u2 })
      )
      (ok true)
    )
  )
)

;; Add a new authorized verifier
(define-public (add-verifier (verifier-id principal))
  (begin
    (asserts! (is-admin tx-sender) (err u5))
    (map-set authorized-verifiers
      { verifier-id: verifier-id }
      { is-authorized: true }
    )
    (ok true)
  )
)

;; Remove an authorized verifier
(define-public (remove-verifier (verifier-id principal))
  (begin
    (asserts! (is-admin tx-sender) (err u5))
    (map-delete authorized-verifiers { verifier-id: verifier-id })
    (ok true)
  )
)

;; Check if a principal is a registered provider
(define-read-only (is-provider-registered (provider-id principal))
  (is-some (map-get? providers { provider-id: provider-id }))
)

;; Check if a principal is an authorized verifier
(define-read-only (is-authorized-verifier (verifier-id principal))
  (default-to false (get is-authorized (map-get? authorized-verifiers { verifier-id: verifier-id })))
)

;; Check if a principal is the admin
(define-read-only (is-admin (user principal))
  (is-eq user (var-get admin))
)

;; Get provider information
(define-read-only (get-provider-info (provider-id principal))
  (map-get? providers { provider-id: provider-id })
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) (err u5))
    (var-set admin new-admin)
    (ok true)
  )
)
