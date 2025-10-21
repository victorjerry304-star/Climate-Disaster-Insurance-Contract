(define-constant err-unauthorized u100)
(define-constant err-not-found u404)
(define-constant err-invalid u400)
(define-constant err-insufficient u402)
(define-constant err-no-disaster u405)

(define-data-var admin principal tx-sender)
(define-data-var next-policy-id uint u1)
(define-data-var reserves uint u0)

(define-map oracles { account: principal } { approved: bool })
(define-map policies { id: uint }
  { holder: principal,
    region: uint,
    start: uint,
    end: uint,
    premium: uint,
    payout: uint,
    active: bool,
    paid: bool })
(define-map disasters { region: uint } { height: uint })

(define-read-only (is-admin (who principal)) (is-eq who (var-get admin)))
(define-read-only (is-approved-oracle (who principal))
  (match (map-get? oracles { account: who }) o (get approved o) false))

(define-read-only (get-reserves) (ok (var-get reserves)))
(define-read-only (get-next-policy-id) (ok (var-get next-policy-id)))

(define-read-only (get-policy (policy-id uint))
  (match (map-get? policies { id: policy-id }) p (ok p) (err err-not-found)))

(define-read-only (get-disaster-height (region uint))
  (match (map-get? disasters { region: region }) d (ok (get height d)) (ok u0)))

(define-read-only (calc-premium (payout uint))
  (let ((x (/ payout u10))) (if (> x u0) (ok x) (ok u1))))

(define-public (set-admin (new principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err err-unauthorized))
    (var-set admin new)
    (ok true)))

(define-public (add-oracle (who principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err err-unauthorized))
    (map-set oracles { account: who } { approved: true })
    (ok true)))

(define-public (remove-oracle (who principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err err-unauthorized))
    (map-set oracles { account: who } { approved: false })
    (ok true)))

(define-public (fund-reserve (amount uint))
  (let ((caller tx-sender))
    (begin
      (asserts! (is-eq caller (var-get admin)) (err err-unauthorized))
      (match (as-contract (stx-transfer? amount caller tx-sender))
        success (begin (var-set reserves (+ (var-get reserves) amount)) (ok true))
        e (err e)))))

(define-public (buy-policy (region uint) (duration uint) (payout uint))
  (let (
        (caller tx-sender)
        (prem (unwrap! (calc-premium payout) (err err-invalid)))
        (pid (var-get next-policy-id))
        (start-height stacks-block-height)
        (end-height (+ stacks-block-height duration))
       )
    (begin
      (asserts! (> duration u0) (err err-invalid))
      (asserts! (> payout u0) (err err-invalid))
      (match (as-contract (stx-transfer? prem caller tx-sender))
        success
          (begin
            (map-set policies { id: pid }
              { holder: caller,
                region: region,
                start: start-height,
                end: end-height,
                premium: prem,
                payout: payout,
                active: true,
                paid: false })
            (var-set next-policy-id (+ pid u1))
            (var-set reserves (+ (var-get reserves) prem))
            (ok pid))
        e (err e)))))

(define-public (report-disaster (region uint))
  (begin
    (asserts! (is-approved-oracle tx-sender) (err err-unauthorized))
    (map-set disasters { region: region } { height: stacks-block-height })
    (ok true)))

(define-read-only (can-claim (policy-id uint))
  (match (map-get? policies { id: policy-id })
    p
    (let (
          (r (get region p))
          (s (get start p))
          (e (get end p))
          (a (get active p))
          (pd (get paid p))
         )
      (ok (and a (not pd)
               (match (map-get? disasters { region: r })
                 d (and (>= (get height d) s) (<= (get height d) e))
                 false))))
    (err err-not-found)))

(define-public (trigger-claim (policy-id uint))
  (match (map-get? policies { id: policy-id })
    p
    (let (
          (holder (get holder p))
          (r (get region p))
          (s (get start p))
          (e (get end p))
          (payout (get payout p))
          (a (get active p))
          (pd (get paid p))
         )
      (begin
        (asserts! (is-eq tx-sender holder) (err err-unauthorized))
        (asserts! a (err err-invalid))
        (asserts! (not pd) (err err-invalid))
        (match (map-get? disasters { region: r })
          d
            (let ((dh (get height d)))
              (begin
                (asserts! (and (>= dh s) (<= dh e)) (err err-no-disaster))
                (asserts! (>= (var-get reserves) payout) (err err-insufficient))
                (match (as-contract (stx-transfer? payout tx-sender holder))
                  success
                    (begin
                      (var-set reserves (- (var-get reserves) payout))
                      (map-set policies { id: policy-id }
                        { holder: holder,
                          region: r,
                          start: s,
                          end: e,
                          premium: (get premium p),
                          payout: payout,
                          active: false,
                          paid: true })
                      (ok true))
                  x (err x))))
          (err err-no-disaster))))
    (err err-not-found)))

(define-public (expire-policy (policy-id uint))
  (match (map-get? policies { id: policy-id })
    p
    (let ((a (get active p)) (pd (get paid p)))
      (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err err-unauthorized))
        (asserts! a (err err-invalid))
        (asserts! (not pd) (err err-invalid))
        (asserts! (> stacks-block-height (get end p)) (err err-invalid))
        (map-set policies { id: policy-id }
          { holder: (get holder p),
            region: (get region p),
            start: (get start p),
            end: (get end p),
            premium: (get premium p),
            payout: (get payout p),
            active: false,
            paid: false })
        (ok true)))
    (err err-not-found)))

(define-read-only (list-policy-core (policy-id uint))
  (match (map-get? policies { id: policy-id }) p
    (ok { holder: (get holder p), region: (get region p), start: (get start p), end: (get end p), premium: (get premium p), payout: (get payout p), active: (get active p), paid: (get paid p) })
    (err err-not-found)))

(define-read-only (is-oracle (who principal))
  (ok (is-approved-oracle who)))

(define-public (update-payout (policy-id uint) (new-payout uint))
  (match (map-get? policies { id: policy-id })
    p
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err err-unauthorized))
      (asserts! (not (get paid p)) (err err-invalid))
      (map-set policies { id: policy-id }
        { holder: (get holder p),
          region: (get region p),
          start: (get start p),
          end: (get end p),
          premium: (get premium p),
          payout: new-payout,
          active: (get active p),
          paid: (get paid p) })
      (ok true))
    (err err-not-found)))

(define-public (extend-policy (policy-id uint) (extra-duration uint))
  (match (map-get? policies { id: policy-id })
    p
    (let ((caller tx-sender) (prem (unwrap! (calc-premium (/ (get payout p) u5)) (err err-invalid))))
      (begin
        (asserts! (is-eq caller (get holder p)) (err err-unauthorized))
        (asserts! (get active p) (err err-invalid))
        (asserts! (> extra-duration u0) (err err-invalid))
        (match (as-contract (stx-transfer? prem caller tx-sender))
          success
            (begin
              (map-set policies { id: policy-id }
                { holder: (get holder p),
                  region: (get region p),
                  start: (get start p),
                  end: (+ (get end p) extra-duration),
                  premium: (+ (get premium p) prem),
                  payout: (get payout p),
                  active: (get active p),
                  paid: (get paid p) })
              (var-set reserves (+ (var-get reserves) prem))
              (ok true))
          e (err e))))
    (err err-not-found)))


