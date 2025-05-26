;; Research Institution Verification Contract
;; Validates and manages rare disease research institutions

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_DATA (err u103))

;; Data Variables
(define-data-var next-institution-id uint u1)

;; Data Maps
(define-map institutions
  { institution-id: uint }
  {
    name: (string-ascii 100),
    address: principal,
    verification-date: uint,
    status: (string-ascii 20),
    specialization: (string-ascii 50),
    contact-info: (string-ascii 200)
  }
)

(define-map institution-by-address
  { address: principal }
  { institution-id: uint }
)

(define-map authorized-verifiers
  { verifier: principal }
  { authorized: bool }
)

;; Public Functions
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set authorized-verifiers { verifier: verifier } { authorized: true })
    (ok true)
  )
)

(define-public (verify-institution
  (name (string-ascii 100))
  (address principal)
  (specialization (string-ascii 50))
  (contact-info (string-ascii 200)))
  (let
    (
      (institution-id (var-get next-institution-id))
      (is-verifier (default-to false (get authorized (map-get? authorized-verifiers { verifier: tx-sender }))))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) is-verifier) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? institution-by-address { address: address })) ERR_ALREADY_VERIFIED)
    (asserts! (> (len name) u0) ERR_INVALID_DATA)

    (map-set institutions
      { institution-id: institution-id }
      {
        name: name,
        address: address,
        verification-date: block-height,
        status: "verified",
        specialization: specialization,
        contact-info: contact-info
      }
    )

    (map-set institution-by-address { address: address } { institution-id: institution-id })
    (var-set next-institution-id (+ institution-id u1))
    (ok institution-id)
  )
)

(define-public (update-institution-status (institution-id uint) (new-status (string-ascii 20)))
  (let
    (
      (institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR_NOT_FOUND))
      (is-verifier (default-to false (get authorized (map-get? authorized-verifiers { verifier: tx-sender }))))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) is-verifier) ERR_NOT_AUTHORIZED)

    (map-set institutions
      { institution-id: institution-id }
      (merge institution { status: new-status })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-institution (institution-id uint))
  (map-get? institutions { institution-id: institution-id })
)

(define-read-only (get-institution-by-address (address principal))
  (match (map-get? institution-by-address { address: address })
    entry (map-get? institutions { institution-id: (get institution-id entry) })
    none
  )
)

(define-read-only (is-verified-institution (address principal))
  (match (get-institution-by-address address)
    institution (is-eq (get status institution) "verified")
    false
  )
)

(define-read-only (get-total-institutions)
  (- (var-get next-institution-id) u1)
)
