;; Patient Identity Contract
;; Securely manages participant profiles with privacy controls

(define-data-var admin principal tx-sender)

;; Patient profiles with minimal on-chain data
(define-map patients
  { patient-id: principal }
  {
    consent-status: bool,
    data-hash: (buff 32),
    registration-date: uint,
    last-updated: uint
  }
)

;; Access control for patient data
(define-map data-access
  { patient-id: principal, provider-id: principal }
  {
    is-authorized: bool,
    access-level: uint,
    expiration-height: uint
  }
)

;; Register a new patient
(define-public (register-patient (data-hash (buff 32)))
  (begin
    (asserts! (not (is-patient-registered tx-sender)) (err u1))
    (map-set patients
      { patient-id: tx-sender }
      {
        consent-status: true,
        data-hash: data-hash,
        registration-date: block-height,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

;; Update patient profile
(define-public (update-patient-profile (data-hash (buff 32)))
  (begin
    (asserts! (is-patient-registered tx-sender) (err u2))
    (let ((patient-data (unwrap! (map-get? patients { patient-id: tx-sender }) (err u3))))
      (map-set patients
        { patient-id: tx-sender }
        (merge patient-data {
          data-hash: data-hash,
          last-updated: block-height
        })
      )
      (ok true)
    )
  )
)

;; Grant access to a provider
(define-public (grant-access (provider-id principal) (access-level uint) (duration uint))
  (begin
    (asserts! (is-patient-registered tx-sender) (err u2))
    (map-set data-access
      { patient-id: tx-sender, provider-id: provider-id }
      {
        is-authorized: true,
        access-level: access-level,
        expiration-height: (+ block-height duration)
      }
    )
    (ok true)
  )
)

;; Revoke access from a provider
(define-public (revoke-access (provider-id principal))
  (begin
    (asserts! (is-patient-registered tx-sender) (err u2))
    (map-delete data-access { patient-id: tx-sender, provider-id: provider-id })
    (ok true)
  )
)

;; Update consent status
(define-public (update-consent (consent-status bool))
  (begin
    (asserts! (is-patient-registered tx-sender) (err u2))
    (let ((patient-data (unwrap! (map-get? patients { patient-id: tx-sender }) (err u3))))
      (map-set patients
        { patient-id: tx-sender }
        (merge patient-data { consent-status: consent-status })
      )
      (ok true)
    )
  )
)

;; Check if a principal is a registered patient
(define-read-only (is-patient-registered (patient-id principal))
  (is-some (map-get? patients { patient-id: patient-id }))
)

;; Check if a provider has access to a patient's data
(define-read-only (check-access (patient-id principal) (provider-id principal))
  (let ((access-data (map-get? data-access { patient-id: patient-id, provider-id: provider-id })))
    (if (is-some access-data)
      (let ((access (unwrap-panic access-data)))
        (and
          (get is-authorized access)
          (< block-height (get expiration-height access))
        )
      )
      false
    )
  )
)

;; Get patient consent status
(define-read-only (get-patient-consent (patient-id principal))
  (default-to false (get consent-status (map-get? patients { patient-id: patient-id })))
)

;; Get patient data hash (only if authorized)
(define-read-only (get-patient-data-hash (patient-id principal))
  (let ((patient-data (map-get? patients { patient-id: patient-id })))
    (if (or
          (is-eq tx-sender patient-id)
          (check-access patient-id tx-sender)
        )
      (get data-hash (default-to
        { consent-status: false, data-hash: 0x, registration-date: u0, last-updated: u0 }
        patient-data))
      0x
    )
  )
)

;; Check if a principal is the admin
(define-read-only (is-admin (user principal))
  (is-eq user (var-get admin))
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) (err u5))
    (var-set admin new-admin)
    (ok true)
  )
)
