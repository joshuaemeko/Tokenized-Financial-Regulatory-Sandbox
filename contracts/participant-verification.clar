;; Participant Verification Contract
;; Validates and manages sandbox participants

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Participant status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)
(define-constant STATUS_SUSPENDED u3)

;; Data structures
(define-map participants
  { participant: principal }
  {
    status: uint,
    verification-date: uint,
    compliance-score: uint,
    entity-type: (string-ascii 50)
  }
)

(define-map participant-documents
  { participant: principal, doc-id: uint }
  {
    document-hash: (buff 32),
    document-type: (string-ascii 30),
    submitted-at: uint
  }
)

(define-data-var next-doc-id uint u1)

;; Public functions
(define-public (register-participant (entity-type (string-ascii 50)))
  (let ((participant tx-sender))
    (asserts! (is-none (map-get? participants { participant: participant })) ERR_ALREADY_VERIFIED)
    (map-set participants
      { participant: participant }
      {
        status: STATUS_PENDING,
        verification-date: u0,
        compliance-score: u0,
        entity-type: entity-type
      }
    )
    (ok true)
  )
)

(define-public (verify-participant (participant principal) (compliance-score uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? participants { participant: participant })) ERR_NOT_FOUND)
    (map-set participants
      { participant: participant }
      {
        status: STATUS_VERIFIED,
        verification-date: block-height,
        compliance-score: compliance-score,
        entity-type: (get entity-type (unwrap-panic (map-get? participants { participant: participant })))
      }
    )
    (ok true)
  )
)

(define-public (submit-document (document-hash (buff 32)) (document-type (string-ascii 30)))
  (let ((doc-id (var-get next-doc-id)))
    (map-set participant-documents
      { participant: tx-sender, doc-id: doc-id }
      {
        document-hash: document-hash,
        document-type: document-type,
        submitted-at: block-height
      }
    )
    (var-set next-doc-id (+ doc-id u1))
    (ok doc-id)
  )
)

(define-public (update-participant-status (participant principal) (new-status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? participants { participant: participant })) ERR_NOT_FOUND)
    (asserts! (<= new-status STATUS_SUSPENDED) ERR_INVALID_STATUS)
    (let ((current-data (unwrap-panic (map-get? participants { participant: participant }))))
      (map-set participants
        { participant: participant }
        (merge current-data { status: new-status })
      )
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-participant-info (participant principal))
  (map-get? participants { participant: participant })
)

(define-read-only (is-verified (participant principal))
  (match (map-get? participants { participant: participant })
    participant-data (is-eq (get status participant-data) STATUS_VERIFIED)
    false
  )
)

(define-read-only (get-document (participant principal) (doc-id uint))
  (map-get? participant-documents { participant: participant, doc-id: doc-id })
)
