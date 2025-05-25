;; Outcome Assessment Contract
;; Evaluates innovation results and generates reports

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_ASSESSMENT_EXISTS (err u501))
(define-constant ERR_NOT_FOUND (err u502))
(define-constant ERR_INVALID_SCORE (err u503))

;; Assessment status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_IN_PROGRESS u1)
(define-constant STATUS_COMPLETED u2)
(define-constant STATUS_PUBLISHED u3)

;; Data structures
(define-map assessments
  { assessment-id: uint }
  {
    innovation-id: uint,
    test-id: uint,
    assessor: principal,
    status: uint,
    overall-score: uint,
    risk-score: uint,
    compliance-score: uint,
    innovation-score: uint,
    market-impact-score: uint,
    created-at: uint,
    completed-at: uint
  }
)

(define-map assessment-criteria
  { assessment-id: uint, criteria-name: (string-ascii 50) }
  {
    score: uint,
    weight: uint,
    comments: (string-ascii 300),
    evidence: (string-ascii 200)
  }
)

(define-map assessment-recommendations
  { assessment-id: uint }
  {
    recommendation: (string-ascii 500),
    next-steps: (string-ascii 300),
    regulatory-implications: (string-ascii 300),
    market-readiness: uint
  }
)

(define-data-var next-assessment-id uint u1)

;; Public functions
(define-public (create-assessment (innovation-id uint) (test-id uint))
  (let ((assessment-id (var-get next-assessment-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? assessments { assessment-id: assessment-id })) ERR_ASSESSMENT_EXISTS)
    (map-set assessments
      { assessment-id: assessment-id }
      {
        innovation-id: innovation-id,
        test-id: test-id,
        assessor: tx-sender,
        status: STATUS_PENDING,
        overall-score: u0,
        risk-score: u0,
        compliance-score: u0,
        innovation-score: u0,
        market-impact-score: u0,
        created-at: block-height,
        completed-at: u0
      }
    )
    (var-set next-assessment-id (+ assessment-id u1))
    (ok assessment-id)
  )
)

(define-public (start-assessment (assessment-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? assessments { assessment-id: assessment-id })) ERR_NOT_FOUND)
    (let ((assessment-data (unwrap-panic (map-get? assessments { assessment-id: assessment-id }))))
      (map-set assessments
        { assessment-id: assessment-id }
        (merge assessment-data { status: STATUS_IN_PROGRESS })
      )
    )
    (ok true)
  )
)

(define-public (score-criteria
  (assessment-id uint)
  (criteria-name (string-ascii 50))
  (score uint)
  (weight uint)
  (comments (string-ascii 300))
  (evidence (string-ascii 200)))
  (begin
    (asserts! (is-some (map-get? assessments { assessment-id: assessment-id })) ERR_NOT_FOUND)
    (asserts! (<= score u100) ERR_INVALID_SCORE)
    (asserts! (<= weight u100) ERR_INVALID_SCORE)
    (let ((assessment-data (unwrap-panic (map-get? assessments { assessment-id: assessment-id }))))
      (asserts! (is-eq (get assessor assessment-data) tx-sender) ERR_UNAUTHORIZED)
      (map-set assessment-criteria
        { assessment-id: assessment-id, criteria-name: criteria-name }
        {
          score: score,
          weight: weight,
          comments: comments,
          evidence: evidence
        }
      )
    )
    (ok true)
  )
)

(define-public (finalize-assessment
  (assessment-id uint)
  (overall-score uint)
  (risk-score uint)
  (compliance-score uint)
  (innovation-score uint)
  (market-impact-score uint))
  (begin
    (asserts! (is-some (map-get? assessments { assessment-id: assessment-id })) ERR_NOT_FOUND)
    (asserts! (<= overall-score u100) ERR_INVALID_SCORE)
    (asserts! (<= risk-score u100) ERR_INVALID_SCORE)
    (asserts! (<= compliance-score u100) ERR_INVALID_SCORE)
    (asserts! (<= innovation-score u100) ERR_INVALID_SCORE)
    (asserts! (<= market-impact-score u100) ERR_INVALID_SCORE)
    (let ((assessment-data (unwrap-panic (map-get? assessments { assessment-id: assessment-id }))))
      (asserts! (is-eq (get assessor assessment-data) tx-sender) ERR_UNAUTHORIZED)
      (map-set assessments
        { assessment-id: assessment-id }
        (merge assessment-data {
          status: STATUS_COMPLETED,
          overall-score: overall-score,
          risk-score: risk-score,
          compliance-score: compliance-score,
          innovation-score: innovation-score,
          market-impact-score: market-impact-score,
          completed-at: block-height
        })
      )
    )
    (ok true)
  )
)

(define-public (add-recommendations
  (assessment-id uint)
  (recommendation (string-ascii 500))
  (next-steps (string-ascii 300))
  (regulatory-implications (string-ascii 300))
  (market-readiness uint))
  (begin
    (asserts! (is-some (map-get? assessments { assessment-id: assessment-id })) ERR_NOT_FOUND)
    (asserts! (<= market-readiness u100) ERR_INVALID_SCORE)
    (let ((assessment-data (unwrap-panic (map-get? assessments { assessment-id: assessment-id }))))
      (asserts! (is-eq (get assessor assessment-data) tx-sender) ERR_UNAUTHORIZED)
      (map-set assessment-recommendations
        { assessment-id: assessment-id }
        {
          recommendation: recommendation,
          next-steps: next-steps,
          regulatory-implications: regulatory-implications,
          market-readiness: market-readiness
        }
      )
    )
    (ok true)
  )
)

(define-public (publish-assessment (assessment-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? assessments { assessment-id: assessment-id })) ERR_NOT_FOUND)
    (let ((assessment-data (unwrap-panic (map-get? assessments { assessment-id: assessment-id }))))
      (asserts! (is-eq (get status assessment-data) STATUS_COMPLETED) ERR_INVALID_SCORE)
      (map-set assessments
        { assessment-id: assessment-id }
        (merge assessment-data { status: STATUS_PUBLISHED })
      )
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-assessment (assessment-id uint))
  (map-get? assessments { assessment-id: assessment-id })
)

(define-read-only (get-assessment-criteria (assessment-id uint) (criteria-name (string-ascii 50)))
  (map-get? assessment-criteria { assessment-id: assessment-id, criteria-name: criteria-name })
)

(define-read-only (get-assessment-recommendations (assessment-id uint))
  (map-get? assessment-recommendations { assessment-id: assessment-id })
)

(define-read-only (is-assessment-published (assessment-id uint))
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment-data (is-eq (get status assessment-data) STATUS_PUBLISHED)
    false
  )
)

(define-read-only (get-assessment-score (assessment-id uint))
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment-data (some (get overall-score assessment-data))
    none
  )
)
