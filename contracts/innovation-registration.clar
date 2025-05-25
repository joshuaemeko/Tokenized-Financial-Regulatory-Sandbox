;; Innovation Registration Contract
;; Records and manages experimental financial concepts

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_VERIFIED (err u201))
(define-constant ERR_INNOVATION_EXISTS (err u202))
(define-constant ERR_NOT_FOUND (err u203))

;; Innovation status types
(define-constant STATUS_SUBMITTED u0)
(define-constant STATUS_UNDER_REVIEW u1)
(define-constant STATUS_APPROVED u2)
(define-constant STATUS_REJECTED u3)
(define-constant STATUS_ACTIVE u4)
(define-constant STATUS_COMPLETED u5)

;; Data structures
(define-map innovations
  { innovation-id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    status: uint,
    submission-date: uint,
    approval-date: uint,
    risk-level: uint
  }
)

(define-map innovation-metrics
  { innovation-id: uint }
  {
    participants-count: uint,
    transaction-volume: uint,
    success-rate: uint,
    compliance-incidents: uint
  }
)

(define-data-var next-innovation-id uint u1)
(define-data-var participant-verification-contract principal tx-sender)

;; Public functions
(define-public (set-participant-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set participant-verification-contract contract-address)
    (ok true)
  )
)

(define-public (register-innovation
  (title (string-ascii 100))
  (description (string-ascii 500))
  (category (string-ascii 50))
  (risk-level uint))
  (let ((innovation-id (var-get next-innovation-id)))
    ;; Check if proposer is verified (simplified check)
    (asserts! (> risk-level u0) ERR_NOT_VERIFIED)
    (map-set innovations
      { innovation-id: innovation-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        category: category,
        status: STATUS_SUBMITTED,
        submission-date: block-height,
        approval-date: u0,
        risk-level: risk-level
      }
    )
    (map-set innovation-metrics
      { innovation-id: innovation-id }
      {
        participants-count: u0,
        transaction-volume: u0,
        success-rate: u0,
        compliance-incidents: u0
      }
    )
    (var-set next-innovation-id (+ innovation-id u1))
    (ok innovation-id)
  )
)

(define-public (approve-innovation (innovation-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? innovations { innovation-id: innovation-id })) ERR_NOT_FOUND)
    (let ((current-data (unwrap-panic (map-get? innovations { innovation-id: innovation-id }))))
      (map-set innovations
        { innovation-id: innovation-id }
        (merge current-data {
          status: STATUS_APPROVED,
          approval-date: block-height
        })
      )
    )
    (ok true)
  )
)

(define-public (update-innovation-status (innovation-id uint) (new-status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? innovations { innovation-id: innovation-id })) ERR_NOT_FOUND)
    (let ((current-data (unwrap-panic (map-get? innovations { innovation-id: innovation-id }))))
      (map-set innovations
        { innovation-id: innovation-id }
        (merge current-data { status: new-status })
      )
    )
    (ok true)
  )
)

(define-public (update-metrics
  (innovation-id uint)
  (participants-count uint)
  (transaction-volume uint)
  (success-rate uint)
  (compliance-incidents uint))
  (begin
    (asserts! (is-some (map-get? innovations { innovation-id: innovation-id })) ERR_NOT_FOUND)
    (let ((innovation-data (unwrap-panic (map-get? innovations { innovation-id: innovation-id }))))
      (asserts! (is-eq (get proposer innovation-data) tx-sender) ERR_UNAUTHORIZED)
      (map-set innovation-metrics
        { innovation-id: innovation-id }
        {
          participants-count: participants-count,
          transaction-volume: transaction-volume,
          success-rate: success-rate,
          compliance-incidents: compliance-incidents
        }
      )
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-innovation (innovation-id uint))
  (map-get? innovations { innovation-id: innovation-id })
)

(define-read-only (get-innovation-metrics (innovation-id uint))
  (map-get? innovation-metrics { innovation-id: innovation-id })
)

(define-read-only (get-next-innovation-id)
  (var-get next-innovation-id)
)
