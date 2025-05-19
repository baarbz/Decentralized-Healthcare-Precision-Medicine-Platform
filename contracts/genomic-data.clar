;; Genomic Data Contract
;; Records genetic information securely with strict access controls

(define-data-var admin principal tx-sender)

;; Genomic data records - stores references to off-chain data
(define-map genomic-records
  { patient-id: principal }
  {
    data-hash: (buff 32),
    metadata-hash: (buff 32),
    timestamp: uint,
    version: uint
  }
)

;; Access log for genomic data
(define-map access-log
  { record-id: uint }
  {
    patient-id: principal,
    accessor-id: principal,
    purpose: (string-utf8 100),
    timestamp: uint
  }
)

;; Counter for access log records
(define-data-var access-counter uint u0)

;; Store genomic data reference (patient can store their own data)
(define-public (store-genomic-data (data-hash (buff 32)) (metadata-hash (buff 32)))
  (begin
    (map-set genomic-records
      { patient-id: tx-sender }
      {
        data-hash: data-hash,
        metadata-hash: metadata-hash,
        timestamp: block-height,
        version: u1
      }
    )
    (ok true)
  )
)

;; Update genomic data reference
(define-public (update-genomic-data (data-hash (buff 32)) (metadata-hash (buff 32)))
  (begin
    (asserts! (has-genomic-record tx-sender) (err u1))
    (let ((current-record (unwrap! (map-get? genomic-records { patient-id: tx-sender }) (err u2))))
      (map-set genomic-records
        { patient-id: tx-sender }
        {
          data-hash: data-hash,
          metadata-hash: metadata-hash,
          timestamp: block-height,
          version: (+ (get version current-record) u1)
        }
      )
      (ok true)
    )
  )
)

;; Provider stores genomic data on behalf of patient (requires patient identity contract)
(define-public (provider-store-genomic-data
                (patient-id principal)
                (data-hash (buff 32))
                (metadata-hash (buff 32))
                (purpose (string-utf8 100)))
  (begin
    ;; This would check the patient-identity contract for authorization
    ;; For simplicity, we're just checking if the provider is the admin
    (asserts! (is-admin tx-sender) (err u3))

    (map-set genomic-records
      { patient-id: patient-id }
      {
        data-hash: data-hash,
        metadata-hash: metadata-hash,
        timestamp: block-height,
        version: u1
      }
    )

    ;; Log the access
    (let ((log-id (var-get access-counter)))
      (var-set access-counter (+ log-id u1))
      (map-set access-log
        { record-id: log-id }
        {
          patient-id: patient-id,
          accessor-id: tx-sender,
          purpose: purpose,
          timestamp: block-height
        }
      )
    )

    (ok true)
  )
)

;; Access genomic data (with logging)
(define-public (access-genomic-data (patient-id principal) (purpose (string-utf8 100)))
  (begin
    (asserts! (has-genomic-record patient-id) (err u1))

    ;; This would check the patient-identity contract for authorization
    ;; For simplicity, we're just checking if the accessor is the admin or the patient
    (asserts! (or (is-eq tx-sender patient-id) (is-admin tx-sender)) (err u3))

    ;; Log the access
    (let ((log-id (var-get access-counter)))
      (var-set access-counter (+ log-id u1))
      (map-set access-log
        { record-id: log-id }
        {
          patient-id: patient-id,
          accessor-id: tx-sender,
          purpose: purpose,
          timestamp: block-height
        }
      )
    )

    (ok (unwrap! (map-get? genomic-records { patient-id: patient-id }) (err u2)))
  )
)

;; Check if a patient has a genomic record
(define-read-only (has-genomic-record (patient-id principal))
  (is-some (map-get? genomic-records { patient-id: patient-id }))
)

;; Get genomic data metadata (public function, but actual data access is controlled)
(define-read-only (get-genomic-metadata (patient-id principal))
  (map-get? genomic-records { patient-id: patient-id })
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
