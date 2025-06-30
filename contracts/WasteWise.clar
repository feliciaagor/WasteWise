;; WasteWise - Waste reduction impact tracking and sustainability rewards platform
(define-data-var sustainability-manager principal tx-sender)
(define-data-var total-waste-diverted uint u0)
(define-data-var eco-reward-multiplier uint u30) ;; reward points per kg diverted
(define-data-var last-reward-calculation uint u0)

(define-map participant-diversion principal uint)
(define-map waste-categories principal (string-utf8 64))
(define-map approved-waste-types (string-utf8 64) bool)

;; Error codes
(define-constant err-unauthorized-manager (err u1400))
(define-constant err-manager-already-assigned (err u1401))
(define-constant err-invalid-waste-amount (err u1402))
(define-constant err-no-rewards-pending (err u1403))
(define-constant err-no-waste-diversion (err u1404))
(define-constant err-invalid-waste-category (err u1405))
(define-constant err-waste-type-not-approved (err u1406))

;; Verify manager authorization
(define-private (is-sustainability-manager (caller principal))
  (begin
    (asserts! (is-eq caller (var-get sustainability-manager)) err-unauthorized-manager)
    (ok true)))

;; Initialize waste reduction tracking program
(define-public (launch-waste-reduction-program (manager principal))
  (begin
    (asserts! (is-none (map-get? participant-diversion manager)) err-manager-already-assigned)
    (var-set sustainability-manager manager)
    (ok "WasteWise waste reduction program launched")))

;; Approve waste category for tracking
(define-public (approve-waste-category (category (string-utf8 64)))
  (begin
    (try! (is-sustainability-manager tx-sender))
    (asserts! (> (len category) u0) err-invalid-waste-category)
    (map-set approved-waste-types category true)
    (ok "Waste category approved for tracking")))

;; Record waste diversion activity
(define-public (record-waste-diversion (kg-diverted uint) (waste-category (string-utf8 64)))
  (begin
    (asserts! (> kg-diverted u0) err-invalid-waste-amount)
    (asserts! (default-to false (map-get? approved-waste-types waste-category)) err-waste-type-not-approved)
    
    (let ((current-diversion (default-to u0 (map-get? participant-diversion tx-sender))))
      (map-set participant-diversion tx-sender (+ current-diversion kg-diverted))
      (map-set waste-categories tx-sender waste-category)
      (var-set total-waste-diverted (+ (var-get total-waste-diverted) kg-diverted))
      (ok (+ current-diversion kg-diverted)))))

;; Calculate sustainability rewards
(define-public (calculate-sustainability-rewards)
  (begin
    (try! (is-sustainability-manager tx-sender))
    (let ((current-calculation (+ (var-get last-reward-calculation) u1))
          (total-diversion (var-get total-waste-diverted)))
      (asserts! (> total-diversion (var-get last-reward-calculation)) err-no-rewards-pending)
      
      (let ((reward-pool (* (var-get eco-reward-multiplier) total-diversion)))
        (var-set last-reward-calculation current-calculation)
        (ok reward-pool)))))

;; Claim waste reduction rewards
(define-public (claim-waste-reduction-rewards)
  (begin
    (let ((participant-diversion-amount (default-to u0 (map-get? participant-diversion tx-sender))))
      (asserts! (> participant-diversion-amount u0) err-no-waste-diversion)
      
      (let ((total-diversion (var-get total-waste-diverted))
            (base-rewards (* (var-get eco-reward-multiplier) participant-diversion-amount))
            (diversion-ratio (/ (* participant-diversion-amount u100000) total-diversion)))
        
        (let ((final-rewards (/ (* diversion-ratio base-rewards) u100000)))
          (map-delete participant-diversion tx-sender)
          (map-delete waste-categories tx-sender)
          (var-set total-waste-diverted (- (var-get total-waste-diverted) participant-diversion-amount))
          (ok (+ participant-diversion-amount final-rewards)))))))

;; Read-only functions
(define-read-only (get-participant-diversion (participant principal))
  (default-to u0 (map-get? participant-diversion participant)))

(define-read-only (get-waste-category (participant principal))
  (map-get? waste-categories participant))

(define-read-only (get-total-waste-diverted)
  (var-get total-waste-diverted))

(define-read-only (is-waste-category-approved (category (string-utf8 64)))
  (default-to false (map-get? approved-waste-types category)))