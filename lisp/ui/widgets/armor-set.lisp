;;;; armor-set.lisp

(in-package #:monster-avengers.simple-web)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (enable-jsx-reader))

(def-widget query-fail-alert (language)
    ()
  #jsx(:div ((class-name "alert alert-info"))
            (lang-text ("en" "Your query does not return anything.")
                       ("zh" "没有找到满足条件的配装."))))

(def-widget in-progress-alert (language)
    ()
  #jsx(:div ((class-name "alert alert-warning"))
            (lang-text ("en" "Search in progress ...")
                       ("zh" "搜索中，请稍候 ..."))))

(def-widget slots-text (holes occupied)
    ()
  #jsx(:div () 
            (chain (array 0 1 2)
                   (map (lambda (i)
                          (if (< i holes)
                              (if (< i occupied)
                                  (:span ((style :border-radius "50%"
                                                 :background "#000"
                                                 :display "inline-block"
                                                 :margin-right "2px"
                                                 :width "12px"
                                                 :height "12px")))
                                  (:span ((style :border-radius "50%"
                                                 :border "1px solid #000"
                                                 :display "inline-block"
                                                 :margin-right "2px"
                                                 :width "12px"
                                                 :height "12px"))))
                              (:span ((style :border "1px solid #000"
                                             :display "inline-block"
                                             :margin-left "2px"
                                             :margin-right "2px"
                                             :margin-bottom "5px"
                                             :width "8px"
                                             :height "1px")))))))))


(def-widget armor-display (language part armor appender filter)
    ((state (expanded false)))
  #jsx(:tr ()
           (:td ((style :text-align "center")) 
                (:img ((src (+ "img/" part ".png"))
                       (style :height "20px"))))
           (:td ((style :font-family "monospace"
                        :text-align "center"))
                (@ armor rare))
           (:td ((style :text-align "center")) 
                (:button ((class-name "btn btn-default btn-xs")
                          ("data-toggle" "collapse")
                          ("data-placement" "left")
                          (title (if (and (@ armor material)
                                          (> (@ armor material length) 0))
                                     (lang-text ("zh" (chain armor material
                                                             (map (lambda (x) (@ x jp)))))
                                                ("en" (chain armor material
                                                             (map (lambda (x) (@ x en))))))
                                     ""))
                          (on-click (lambda () 
                                      (let ((original (local-state expanded)))
                                        (chain this (set-state 
                                                     (create expanded (not original))))))))
                         (if (= "" (@ armor name en))
                             "----------"
                             (lang-text ("zh" (@ armor name jp))
                                        ("en" (@ armor name en)))))
                (when (and (local-state expanded)
                           (!= part "gear")
                           (!= part "amulet"))
                  (:div ((style :margin-top "3px"))
                        (:div () (lang-text ("zh" (@ armor name jp))
                                            ("en" (@ armor name en))))
                        (:div ()
                              (lang-text ("en" "Filter this out: ")
                                         ("zh" "过滤掉包含此装备的配装: "))
                              (:button ((class-name "btn btn-default btn-xs")
                                        (on-click (lambda ()
                                                    (funcall appender (@ armor id))
                                                    (funcall filter true))))
                                       (:span ((class-name "glyphicon glyphicon-remove-sign"))))))))
           (:td ((style :text-align "center")) 
                (:slots-text ((holes (@ armor holes))
                              (occupied (@ armor stuffed)))))
           (:td ((style :text-align "center"))
                (if (= "true" (@ armor torsoup))
                    (lang-text ("zh" "胴系统倍加")
                               ("en" "Torso Up"))
                    (chain (@ armor jewels)
                           (map (lambda (jewel)
                                  (+ (lang-text ("zh" (@ jewel name jp))
                                                ("en" (@ jewel name en)))
                                     " x "
                                     (@ jewel num))))
                           (join ", "))))))


(def-widget armor-set-display (language armor-set blacklist-callback filter-callback)
    ((state (jewel-plan-id 0))
     (switch-jewel-plan (id)
                        (chain this (set-state (create jewel-plan-id
                                                       id)))))
  #jsx(:div ((class-name "panel panel-success"))
            (:div ((class-name "panel-heading"))
                  (+ (lang-text ("en" "Armor Set")
                                ("zh" "配装组合"))
                     " - "
                     (lang-text ("en" "Defense: " )
                                ("zh" "防御力: "))
                     (@ armor-set defense)))
            (:table ((class-name "table"))
                    (:tr ()
                         (:th ((class-name "col-md-1")
                               (style :text-align "center")) 
                              "")
                         (:th ((class-name "col-md-1")
                               (style :text-align "center"))
                              (lang-text ("en" "Rare")
                                         ("zh" "稀有度")))
                         (:th ((class-name "col-md-5")
                               (style :text-align "center"))
                              (lang-text ("en" "Armor")
                                         ("zh" "装备名称")))
                         (:th ((class-name "col-md-1")
                               (style :text-align "center")) 
                              (lang-text ("en" "Slots")
                                         ("zh" "装饰珠槽")))
                         (:th ((class-name "col-md-4")
                               (style :text-align "center")) 
                              (lang-text ("en" "Notes")
                                         ("zh" "备注"))))
                    (:armor-display ((part "gear")
                                     (:language language)
                                     (appender blacklist-callback)
                                     (filter filter-callback)
                                     (armor (@ armor-set gear))))
                    (:armor-display ((part "head")
                                     (:language language)
                                     (appender blacklist-callback)
                                     (filter filter-callback)
                                     (armor (@ armor-set head))))
                    (:armor-display ((part "body")
                                     (:language language)
                                     (appender blacklist-callback)
                                     (filter filter-callback)
                                     (armor (@ armor-set body))))
                    (:armor-display ((part "hands")
                                     (:language language)
                                     (appender blacklist-callback)
                                     (filter filter-callback)
                                     (armor (@ armor-set hands))))
                    (:armor-display ((part "waist")
                                     (:language language)
                                     (appender blacklist-callback)
                                     (filter filter-callback)
                                     (armor (@ armor-set waist))))
                    (:armor-display ((part "feet")
                                     (:language language)
                                     (appender blacklist-callback)
                                     (filter filter-callback)
                                     (armor (@ armor-set feet))))
                    (:armor-display ((part "amulet")
                                     (:language language)
                                     (appender blacklist-callback)
                                     (filter filter-callback)
                                     (armor (@ armor-set amulet)))))
            (:div ((class-name "panel-body"))
                  (:div ()
                        (:nav () 
                              (:ul ((class-name "pagination"))
                                   (:li ((class-name "disabled"))
                                        (:a ()
                                            (lang-text ("en" "Decorations Plan")
                                                       ("zh" "装饰珠方案"))))
                                   (chain (@ armor-set jewel-plans)
                                          (map (lambda (x id)
                                                 (if (= id (local-state jewel-plan-id))
                                                     (:li ((class-name "active")
                                                           (on-click 
                                                            (lambda ()
                                                              (funcall (@ this switch-jewel-plan)
                                                                       id))))
                                                          (:a () (1+ id)))
                                                     (:li ((on-click 
                                                            (lambda ()
                                                              (funcall (@ this switch-jewel-plan)
                                                                       id))))
                                                          (:a () (1+ id))))))))))
                  (:p () (let ((content (lang-text ("en" "Active: ")
                                                   ("zh" "发动技能: ")))
                               (skills (lang-text ("zh" (chain (aref (@ armor-set jewel-plans)
                                                                     (local-state jewel-plan-id))
                                                               active
                                                               (map (lambda (x) (@ x jp)))))
                                                  ("en" (chain (aref (@ armor-set jewel-plans)
                                                                     (local-state jewel-plan-id))
                                                               active
                                                               (map (lambda (x) (@ x en))))))))
                           (loop for skill in skills
                              do (setf content (+ content 
                                                  skill
                                                  "  |  ")))
                           content))
                  (:div () (let ((plan (@ (aref (@ armor-set jewel-plans)
                                                (local-state jewel-plan-id))
                                          plan)))
                             (chain plan 
                                    (map (lambda (x)
                                           (:div () (:span ((class-name "label label-warning"))
                                                           (lang-text ("zh" (@ x name jp))
                                                                      ("en" (@ x name en)))
                                                           " x " 
                                                           (@ x num)))))))))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (disable-jsx-reader))
