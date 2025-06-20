;; Stakeholder Profit Distribution Smart Contract
;; 
;; A comprehensive smart contract system for managing equity-based profit sharing
;; among multiple stakeholders. Supports percentage-based ownership allocation,
;; secure profit distribution rounds, blacklist management, and claim tracking.
;;
;; Key Features:
;; - Percentage-based stakeholder management (basis points precision)
;; - Multi-round profit distribution with claim tracking
;; - Stakeholder blacklisting and access control
;; - Emergency withdrawal capabilities
;; - Comprehensive validation and security checks

(define-constant contract-deployer tx-sender)

;; Error constants
;; Access Control Errors
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-BLACKLISTED-STAKEHOLDER (err u101))

;; Initialization Errors  
(define-constant ERR-CONTRACT-ALREADY-INITIALIZED (err u200))
(define-constant ERR-CONTRACT-NOT-INITIALIZED (err u201))

;; Validation Errors
(define-constant ERR-INVALID-PERCENTAGE-VALUE (err u300))
(define-constant ERR-INVALID-MINIMUM-STAKE (err u301))
(define-constant ERR-INVALID-PRINCIPAL-ADDRESS (err u302))
(define-constant ERR-ZERO-AMOUNT-PROVIDED (err u303))

;; Business Logic Errors
(define-constant ERR-PERCENTAGE-LIMIT-EXCEEDED (err u400))
(define-constant ERR-STAKEHOLDER-NOT-FOUND (err u401))
(define-constant ERR-NO-OWNERSHIP-STAKE (err u402))
(define-constant ERR-DISTRIBUTION-ROUND-ACTIVE (err u403))
(define-constant ERR-DISTRIBUTION-ROUND-INACTIVE (err u404))
(define-constant ERR-PROFITS-ALREADY-CLAIMED (err u405))

;; Financial Errors
(define-constant ERR-INSUFFICIENT-CONTRACT-BALANCE (err u500))
(define-constant ERR-TRANSFER-OPERATION-FAILED (err u501))

;; System constants
(define-constant maximum-percentage-basis-points u10000) ;; 100% in basis points
(define-constant default-minimum-stake-amount u1000000) ;; 1 STX in microSTX

;; Contract state variables
(define-data-var contract-initialization-status bool false)
(define-data-var accumulated-contribution-total uint u0)
(define-data-var current-distribution-round-active bool false)
(define-data-var latest-distribution-round-id uint u0)
(define-data-var lifetime-distributed-amount uint u0)
(define-data-var required-minimum-stake-amount uint default-minimum-stake-amount)
(define-data-var allocated-percentage-total uint u0)

;; Data storage maps
(define-map registered-stakeholder-data principal { ownership-percentage: uint })
(define-map stakeholder-accumulated-balances principal uint)
(define-map completed-distribution-rounds uint { distributed-total: uint, completion-timestamp: uint })
(define-map distribution-claim-records { round-id: uint, stakeholder-address: principal } bool)
(define-map stakeholder-blacklist-status principal bool)

;; READ-ONLY QUERY FUNCTIONS

(define-read-only (get-stakeholder-ownership-details (stakeholder-address principal))
  (default-to { ownership-percentage: u0 } (map-get? registered-stakeholder-data stakeholder-address))
)

(define-read-only (get-stakeholder-accumulated-balance (stakeholder-address principal))
  (default-to u0 (map-get? stakeholder-accumulated-balances stakeholder-address))
)

(define-read-only (get-distribution-round-details (round-id uint))
  (map-get? completed-distribution-rounds round-id)
)

(define-read-only (check-profits-claimed-status (round-id uint) (stakeholder-address principal))
  (default-to false (map-get? distribution-claim-records { round-id: round-id, stakeholder-address: stakeholder-address }))
)

(define-read-only (check-stakeholder-blacklist-status (stakeholder-address principal))
  (default-to false (map-get? stakeholder-blacklist-status stakeholder-address))
)

(define-read-only (verify-contract-deployer-access)
  (is-eq tx-sender contract-deployer)
)

(define-read-only (get-contract-initialization-status)
  (var-get contract-initialization-status)
)

(define-read-only (get-distribution-round-active-status)
  (var-get current-distribution-round-active)
)

(define-read-only (get-current-distribution-round-number)
  (var-get latest-distribution-round-id)
)

(define-read-only (get-total-allocated-percentage)
  (var-get allocated-percentage-total)
)

(define-read-only (calculate-claimable-profit-amount (round-id uint) (stakeholder-address principal))
  (let (
    (distribution-round-data (map-get? completed-distribution-rounds round-id))
    (stakeholder-ownership-data (get-stakeholder-ownership-details stakeholder-address))
  )
    (if (and (is-some distribution-round-data) (> (get ownership-percentage stakeholder-ownership-data) u0))
      (let (
        (round-details (unwrap-panic distribution-round-data))
        (ownership-percentage (get ownership-percentage stakeholder-ownership-data))
      )
        (if (check-profits-claimed-status round-id stakeholder-address)
          u0
          (/ (* (get distributed-total round-details) ownership-percentage) maximum-percentage-basis-points)
        )
      )
      u0
    )
  )
)

(define-read-only (get-comprehensive-contract-status)
  {
    contract-deployer: contract-deployer,
    initialization-complete: (var-get contract-initialization-status),
    accumulated-contributions: (var-get accumulated-contribution-total),
    distribution-round-active: (var-get current-distribution-round-active),
    latest-round-number: (var-get latest-distribution-round-id),
    lifetime-distributed-total: (var-get lifetime-distributed-amount),
    minimum-stake-requirement: (var-get required-minimum-stake-amount),
    total-percentage-allocated: (var-get allocated-percentage-total),
    current-contract-balance: (stx-get-balance (as-contract tx-sender))
  }
)

;; PRIVATE VALIDATION FUNCTIONS

(define-private (validate-percentage-within-bounds (percentage-value uint))
  (if (> percentage-value maximum-percentage-basis-points)
    (err ERR-INVALID-PERCENTAGE-VALUE)
    (ok true)
  )
)

(define-private (validate-minimum-stake-amount (minimum-amount uint))
  (if (> minimum-amount u0)
    (ok true)
    (err ERR-INVALID-MINIMUM-STAKE)
  )
)

(define-private (validate-principal-address (user-address principal))
  ;; Validate that the principal is not the contract deployer (to prevent self-assignment)
  ;; and is not the zero address equivalent (contract address)
  (if (and (not (is-eq user-address contract-deployer))
           (not (is-eq user-address (as-contract tx-sender))))
    (ok true)
    (err ERR-INVALID-PRINCIPAL-ADDRESS)
  )
)

(define-private (ensure-contract-deployer-access)
  (if (is-eq tx-sender contract-deployer)
    (ok true)
    (err ERR-UNAUTHORIZED-ACCESS)
  )
)

(define-private (ensure-contract-initialized)
  (if (var-get contract-initialization-status)
    (ok true)
    (err ERR-CONTRACT-NOT-INITIALIZED)
  )
)

(define-private (ensure-contract-not-initialized)
  (if (not (var-get contract-initialization-status))
    (ok true)
    (err ERR-CONTRACT-ALREADY-INITIALIZED)
  )
)

(define-private (ensure-stakeholder-not-blacklisted (user-address principal))
  (if (check-stakeholder-blacklist-status user-address)
    (err ERR-BLACKLISTED-STAKEHOLDER)
    (ok true)
  )
)

(define-private (ensure-distribution-round-inactive)
  (if (not (var-get current-distribution-round-active))
    (ok true)
    (err ERR-DISTRIBUTION-ROUND-ACTIVE)
  )
)

(define-private (ensure-distribution-round-active)
  (if (var-get current-distribution-round-active)
    (ok true)
    (err ERR-DISTRIBUTION-ROUND-INACTIVE)
  )
)

;; CONTRACT INITIALIZATION AND CONFIGURATION

(define-public (initialize-profit-distribution-contract (minimum-stake-requirement uint))
  (begin
    (asserts! (> minimum-stake-requirement u0) (err ERR-INVALID-MINIMUM-STAKE))
    
    (try! (ensure-contract-deployer-access))
    (try! (ensure-contract-not-initialized))
    (try! (validate-minimum-stake-amount minimum-stake-requirement))
    
    (var-set required-minimum-stake-amount minimum-stake-requirement)
    (var-set contract-initialization-status true)
    (ok true)
  )
)

;; STAKEHOLDER MANAGEMENT FUNCTIONS

(define-public (register-new-stakeholder (stakeholder-address principal) (ownership-percentage uint))
  (begin
    (asserts! (<= ownership-percentage maximum-percentage-basis-points) (err ERR-INVALID-PERCENTAGE-VALUE))
    (asserts! (not (is-eq stakeholder-address contract-deployer)) (err ERR-INVALID-PRINCIPAL-ADDRESS))
    (asserts! (not (is-eq stakeholder-address (as-contract tx-sender))) (err ERR-INVALID-PRINCIPAL-ADDRESS))
    
    (try! (ensure-contract-deployer-access))
    (try! (ensure-contract-initialized))
    (try! (ensure-distribution-round-inactive))
    (try! (validate-percentage-within-bounds ownership-percentage))
    
    (if (> (+ (var-get allocated-percentage-total) ownership-percentage) maximum-percentage-basis-points)
      (err ERR-PERCENTAGE-LIMIT-EXCEEDED)
      (begin
        (map-set registered-stakeholder-data stakeholder-address { ownership-percentage: ownership-percentage })
        (map-set stakeholder-accumulated-balances stakeholder-address u0)
        (var-set allocated-percentage-total (+ (var-get allocated-percentage-total) ownership-percentage))
        (ok true)
      )
    )
  )
)

(define-public (update-stakeholder-ownership-percentage (stakeholder-address principal) (new-ownership-percentage uint))
  (let (
    (current-stakeholder-data (get-stakeholder-ownership-details stakeholder-address))
    (previous-percentage (get ownership-percentage current-stakeholder-data))
  )
    (begin
      (asserts! (<= new-ownership-percentage maximum-percentage-basis-points) (err ERR-INVALID-PERCENTAGE-VALUE))
      (asserts! (not (is-eq stakeholder-address contract-deployer)) (err ERR-INVALID-PRINCIPAL-ADDRESS))
      (asserts! (not (is-eq stakeholder-address (as-contract tx-sender))) (err ERR-INVALID-PRINCIPAL-ADDRESS))
      
      (try! (ensure-contract-deployer-access))
      (try! (ensure-contract-initialized))
      (try! (ensure-distribution-round-inactive))
      (try! (validate-percentage-within-bounds new-ownership-percentage))
      
      (if (> (+ (- (var-get allocated-percentage-total) previous-percentage) new-ownership-percentage) maximum-percentage-basis-points)
        (err ERR-PERCENTAGE-LIMIT-EXCEEDED)
        (begin
          (map-set registered-stakeholder-data stakeholder-address { ownership-percentage: new-ownership-percentage })
          (var-set allocated-percentage-total (+ (- (var-get allocated-percentage-total) previous-percentage) new-ownership-percentage))
          (ok true)
        )
      )
    )
  )
)

(define-public (remove-stakeholder-registration (stakeholder-address principal))
  (let (
    (current-stakeholder-data (get-stakeholder-ownership-details stakeholder-address))
    (stakeholder-percentage (get ownership-percentage current-stakeholder-data))
  )
    (begin
      (asserts! (not (is-eq stakeholder-address contract-deployer)) (err ERR-INVALID-PRINCIPAL-ADDRESS))
      (asserts! (not (is-eq stakeholder-address (as-contract tx-sender))) (err ERR-INVALID-PRINCIPAL-ADDRESS))
      
      (try! (ensure-contract-deployer-access))
      (try! (ensure-contract-initialized))
      (try! (ensure-distribution-round-inactive))
      
      (asserts! (> stakeholder-percentage u0) (err ERR-STAKEHOLDER-NOT-FOUND))
      
      (if (map-delete registered-stakeholder-data stakeholder-address)
        (begin
          (var-set allocated-percentage-total (- (var-get allocated-percentage-total) stakeholder-percentage))
          (ok true)
        )
        (err ERR-STAKEHOLDER-NOT-FOUND)
      )
    )
  )
)

;; BLACKLIST MANAGEMENT FUNCTIONS

(define-public (add-stakeholder-to-blacklist (stakeholder-address principal))
  (begin
    (asserts! (not (is-eq stakeholder-address contract-deployer)) (err ERR-INVALID-PRINCIPAL-ADDRESS))
    (asserts! (not (is-eq stakeholder-address (as-contract tx-sender))) (err ERR-INVALID-PRINCIPAL-ADDRESS))
    
    (try! (ensure-contract-deployer-access))
    (try! (ensure-contract-initialized))
    
    (map-set stakeholder-blacklist-status stakeholder-address true)
    (ok true)
  )
)

(define-public (remove-stakeholder-from-blacklist (stakeholder-address principal))
  (begin
    (asserts! (not (is-eq stakeholder-address contract-deployer)) (err ERR-INVALID-PRINCIPAL-ADDRESS))
    (asserts! (not (is-eq stakeholder-address (as-contract tx-sender))) (err ERR-INVALID-PRINCIPAL-ADDRESS))
    
    (try! (ensure-contract-deployer-access))
    (try! (ensure-contract-initialized))
    
    (map-set stakeholder-blacklist-status stakeholder-address false)
    (ok true)
  )
)

;; DISTRIBUTION ROUND MANAGEMENT FUNCTIONS

(define-public (activate-new-distribution-round)
  (begin
    (try! (ensure-contract-deployer-access))
    (try! (ensure-contract-initialized))
    (try! (ensure-distribution-round-inactive))
    
    (var-set current-distribution-round-active true)
    (ok true)
  )
)

(define-public (deactivate-current-distribution-round)
  (begin
    (try! (ensure-contract-deployer-access))
    (try! (ensure-contract-initialized))
    (try! (ensure-distribution-round-active))
    
    (var-set current-distribution-round-active false)
    (ok true)
  )
)

;; CONTRIBUTION FUNCTIONS

(define-public (contribute-all-available-stx)
  (let (
    (contributor-balance (stx-get-balance tx-sender))
  )
    (begin
      (try! (ensure-contract-initialized))
      (try! (ensure-distribution-round-active))
      
      (if (<= contributor-balance u0)
        (err ERR-ZERO-AMOUNT-PROVIDED)
        (match (stx-transfer? contributor-balance tx-sender (as-contract tx-sender))
          transfer-success (begin
            (var-set accumulated-contribution-total (+ (var-get accumulated-contribution-total) contributor-balance))
            (ok contributor-balance)
          )
          transfer-error (err ERR-TRANSFER-OPERATION-FAILED)
        )
      )
    )
  )
)

(define-public (contribute-specific-stx-amount (contribution-amount uint))
  (begin
    (try! (ensure-contract-initialized))
    (try! (ensure-distribution-round-active))
    
    (if (<= contribution-amount u0)
      (err ERR-ZERO-AMOUNT-PROVIDED)
      (match (stx-transfer? contribution-amount tx-sender (as-contract tx-sender))
        transfer-success (begin
          (var-set accumulated-contribution-total (+ (var-get accumulated-contribution-total) contribution-amount))
          (ok contribution-amount)
        )
        transfer-error (err ERR-TRANSFER-OPERATION-FAILED)
      )
    )
  )
)

;; PROFIT DISTRIBUTION FUNCTIONS

(define-public (execute-profit-distribution)
  (let (
    (available-contract-balance (stx-get-balance (as-contract tx-sender)))
    (next-distribution-round-id (+ (var-get latest-distribution-round-id) u1))
  )
    (begin
      (try! (ensure-contract-deployer-access))
      (try! (ensure-contract-initialized))
      (try! (ensure-distribution-round-active))
      
      (if (<= available-contract-balance u0)
        (err ERR-INSUFFICIENT-CONTRACT-BALANCE)
        (begin
          (map-set completed-distribution-rounds next-distribution-round-id { 
            distributed-total: available-contract-balance, 
            completion-timestamp: block-height 
          })
          
          (var-set latest-distribution-round-id next-distribution-round-id)
          (var-set lifetime-distributed-amount (+ (var-get lifetime-distributed-amount) available-contract-balance))
          (var-set accumulated-contribution-total u0)
          (var-set current-distribution-round-active false)
          
          (ok next-distribution-round-id)
        )
      )
    )
  )
)

(define-public (claim-stakeholder-profits (target-distribution-round-id uint))
  (let (
    (distribution-round-data (map-get? completed-distribution-rounds target-distribution-round-id))
    (claimant-ownership-data (get-stakeholder-ownership-details tx-sender))
    (profits-already-claimed (check-profits-claimed-status target-distribution-round-id tx-sender))
  )
    (begin
      (try! (ensure-contract-initialized))
      (try! (ensure-stakeholder-not-blacklisted tx-sender))
      
      (asserts! (is-some distribution-round-data) (err ERR-STAKEHOLDER-NOT-FOUND))
      (asserts! (not profits-already-claimed) (err ERR-PROFITS-ALREADY-CLAIMED))
      (asserts! (> (get ownership-percentage claimant-ownership-data) u0) (err ERR-NO-OWNERSHIP-STAKE))
      
      (let (
        (round-details (unwrap-panic distribution-round-data))
        (ownership-percentage (get ownership-percentage claimant-ownership-data))
        (claimable-profit-amount (/ (* (get distributed-total round-details) ownership-percentage) maximum-percentage-basis-points))
      )
        (begin
          (map-set distribution-claim-records { round-id: target-distribution-round-id, stakeholder-address: tx-sender } true)
          (map-set stakeholder-accumulated-balances tx-sender (+ (get-stakeholder-accumulated-balance tx-sender) claimable-profit-amount))
          
          (match (as-contract (stx-transfer? claimable-profit-amount tx-sender tx-sender))
            transfer-success (ok claimable-profit-amount)
            transfer-error (err ERR-TRANSFER-OPERATION-FAILED)
          )
        )
      )
    )
  )
)

;; EMERGENCY FUNCTIONS

(define-public (emergency-contract-balance-withdrawal)
  (let (
    (total-contract-balance (stx-get-balance (as-contract tx-sender)))
  )
    (begin
      (try! (ensure-contract-deployer-access))
      
      (if (<= total-contract-balance u0)
        (err ERR-INSUFFICIENT-CONTRACT-BALANCE)
        (match (as-contract (stx-transfer? total-contract-balance tx-sender contract-deployer))
          transfer-success (ok total-contract-balance)
          transfer-error (err ERR-TRANSFER-OPERATION-FAILED)
        )
      )
    )
  )
)