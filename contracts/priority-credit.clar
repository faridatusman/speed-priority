;; priority-credit.clar
;; Speed Priority Carbon Credit Marketplace Smart Contract
;; This contract manages the lifecycle of high-speed, high-priority carbon credits 
;; on the Stacks blockchain, focusing on rapid verification and trading.

;; ========== Error Constants ==========
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-INVALID-VALIDATOR (err u201))
(define-constant ERR-ALREADY-REGISTERED (err u202))
(define-constant ERR-NOT-REGISTERED (err u203))
(define-constant ERR-INVALID-DEVELOPER (err u204))
(define-constant ERR-INVALID-CREDIT-ID (err u205))
(define-constant ERR-CREDIT-EXISTS (err u206))
(define-constant ERR-LOW-CREDIT-BALANCE (err u207))
(define-constant ERR-CREDIT-RETIRED (err u208))
(define-constant ERR-LISTING-MISSING (err u209))
(define-constant ERR-INVALID-PRICING (err u210))
(define-constant ERR-LISTING-ACTIVE (err u211))
(define-constant ERR-NOT-LISTING-OWNER (err u212))
(define-constant ERR-TRANSACTION-FAILED (err u213))

;; ========== Data Space Definitions ==========
;; Administrative Control
(define-data-var contract-admin principal tx-sender)

;; Validator Registry
(define-map authorized-validators
  principal
  bool
)

;; Developer Registry
(define-map verified-developers
  {
    developer: principal,
    validator: principal,
  }
  {
    approved: bool,
    registered-at: uint,
    project-name: (string-ascii 100),
  }
)

;; Carbon Credit Metadata
(define-map priority-credits
  { credit-id: uint }
  {
    owner: principal,
    developer: principal,
    volume: uint, ;; in metric tons of CO2e
    project-category: (string-ascii 50),
    geographic-region: (string-ascii 50),
    validation-standard: (string-ascii 50),
    credit-year: uint,
    unique-reference: (string-ascii 100),
    minted-timestamp: uint,
    is-retired: bool,
    retirement-recipient: (optional principal),
    retirement-date: (optional uint),
  }
)

;; Credit Ownership Tracking
(define-map credit-ownership
  {
    owner: principal,
    credit-id: uint,
  }
  {
    active-volume: uint,
    retired-volume: uint,
  }
)

;; Marketplace Listings
(define-map marketplace-offers
  { listing-id: uint }
  {
    seller: principal,
    credit-id: uint,
    volume: uint,
    unit-price: uint, ;; in microSTX per ton
    is-active: bool,
  }
)

;; Global Counters
(define-data-var next-credit-identifier uint u1)
(define-data-var next-listing-identifier uint u1)
(define-data-var total-credits-generated uint u0)
(define-data-var total-credits-decommissioned uint u0)
(define-data-var total-credits-exchanged uint u0)

;; ========== Private Functions ==========
(define-private (is-contract-admin)
  (is-eq tx-sender (var-get contract-admin))
)

(define-private (is-authorized-validator (validator principal))
  (default-to false (map-get? authorized-validators validator))
)

(define-private (is-verified-developer (developer principal))
  (match (map-get? verified-developers {
    developer: developer,
    validator: tx-sender,
  })
    developer-data (get approved developer-data)
    false
  )
)

(define-private (is-valid-credit (credit-id uint))
  (match (map-get? priority-credits { credit-id: credit-id })
    credit-data (not (get is-retired credit-data))
    false
  )
)

(define-private (has-sufficient-credit-balance
    (owner principal)
    (credit-id uint)
    (volume uint)
  )
  (match (map-get? credit-ownership {
    owner: owner,
    credit-id: credit-id,
  })
    balance-data (>= (get active-volume balance-data) volume)
    false
  )
)

;; ========== Read-Only Functions ==========
(define-read-only (get-credit-details (credit-id uint))
  (map-get? priority-credits { credit-id: credit-id })
)

(define-read-only (get-marketplace-listing (listing-id uint))
  (map-get? marketplace-offers { listing-id: listing-id })
)

(define-read-only (get-market-metrics)
  {
    total-minted: (var-get total-credits-generated),
    total-decommissioned: (var-get total-credits-decommissioned),
    total-traded: (var-get total-credits-exchanged),
  }
)

;; ========== Public Functions ==========
;; Administration
(define-public (transfer-administration (new-admin principal))
  (begin
    (asserts! (is-contract-admin) ERR-UNAUTHORIZED)
    (var-set contract-admin new-admin)
    (ok true)
  )
)

(define-public (register-validator (validator principal))
  (begin
    (asserts! (is-contract-admin) ERR-UNAUTHORIZED)
    (asserts! (not (is-authorized-validator validator)) ERR-ALREADY-REGISTERED)
    (map-set authorized-validators validator true)
    (ok true)
  )
)

(define-public (remove-validator (validator principal))
  (begin
    (asserts! (is-contract-admin) ERR-UNAUTHORIZED)
    (asserts! (is-authorized-validator validator) ERR-NOT-REGISTERED)
    (map-delete authorized-validators validator)
    (ok true)
  )
)

;; Developer Management
(define-public (register-project-developer
    (developer principal)
    (project-name (string-ascii 100))
  )
  (begin
    (asserts! (is-authorized-validator tx-sender) ERR-UNAUTHORIZED)
    (map-set verified-developers {
      developer: developer,
      validator: tx-sender,
    } {
      approved: true,
      registered-at: block-height,
      project-name: project-name,
    })
    (ok true)
  )
)

(define-public (suspend-project-developer (developer principal))
  (begin
    (asserts! (is-authorized-validator tx-sender) ERR-UNAUTHORIZED)
    (match (map-get? verified-developers {
      developer: developer,
      validator: tx-sender,
    })
      developer-data (begin
        (map-set verified-developers {
          developer: developer,
          validator: tx-sender,
        }
          (merge developer-data { approved: false })
        )
        (ok true)
      )
      ERR-NOT-REGISTERED
    )
  )
)

;; Marketplace Functions
(define-public (list-credits-for-sale
    (credit-id uint)
    (volume uint)
    (unit-price uint)
  )
  (let (
      (seller tx-sender)
      (listing-id (var-get next-listing-identifier))
    )
    (asserts! (is-valid-credit credit-id) ERR-CREDIT-RETIRED)
    (asserts! (has-sufficient-credit-balance seller credit-id volume)
      ERR-LOW-CREDIT-BALANCE
    )
    (asserts! (> unit-price u0) ERR-INVALID-PRICING)
    
    (map-set marketplace-offers { listing-id: listing-id } {
      seller: seller,
      credit-id: credit-id,
      volume: volume,
      unit-price: unit-price,
      is-active: true,
    })
    
    (var-set next-listing-identifier (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (withdraw-listing (listing-id uint))
  (let ((listing (unwrap! (map-get? marketplace-offers { listing-id: listing-id })
        ERR-LISTING-MISSING
      )))
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-LISTING-OWNER)
    (asserts! (get is-active listing) ERR-LISTING-MISSING)
    
    (map-set marketplace-offers { listing-id: listing-id }
      (merge listing { is-active: false })
    )
    (ok true)
  )
)