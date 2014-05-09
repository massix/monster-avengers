;;;; armor-up.lisp
;;;; Author: BreakDS <breakds@gmail.com>

(in-package #:breakds.monster-avengers.armor-up)


;;; ---------- Constants ----------
(defparameter *foundation-search-cut-off* 2
  "When the number of required-effects <= this cut off value, use
  foundation search only.")

;;; ---------- Utilities ----------

(declaim (inline make-map))
(defun make-map ()
  "Create a hash table with unsigned 64 keys."
  (make-hash-table :test #'eq))

(declaim (inline enqueue-map))
(defun enqueue-map (obj key hash-map)
  (push obj (gethash key hash-map nil)))

(declaim (inline max-map-key))
(defun max-map-key (hash-map)
  (loop for key being the hash-keys of hash-map
     maximize key))

(declaim (inline first-n))
(defun first-n (input-list n)
  (let ((l input-list))
    (values
     (loop 
        for i below n
        for x = (pop l)
        until (null x)
        collect x)
     l)))

(defmacro classify-to-map (&key (in nil) (across nil) (key nil) (when nil))
  "This anarchy macro introduces the variable INDIVIDUAL and INDIVIDUAL-KEY."
  (if (or (and in across)
	  (and (null in) (null across)))
      (error "One and only one of :in and :across should be supplied.")
      (with-gensyms (result)
	`(let ((,result (make-map)))
	   (loop for individual ,@(if across
				      (list 'across across)
				      (list 'in in))
	      do (let ((individual-key ,key))
		   ,(if when
			`(when ,when
			   (enqueue-map individual individual-key ,result))
			`(enqueue-map individual individual-key ,result))))
	   ,result))))

(defmacro merge-maps ((map-a map-b) &key new-key new-obj (to nil) (when nil))
  (with-gensyms (merged-map)
    `(,@(if to
	    `(progn)
	    `(let ((,merged-map (make-map)))))
	(loop
	   for ,(symb map-a '-key) being the hash-keys of ,map-a
	   for ,(symb map-a '-val) being the hash-values of ,map-a
	   do (loop 
		 for ,(symb map-b '-key) being the hash-keys of ,map-b
		 for ,(symb map-b '-val) being the hash-values of ,map-b
		 do (let ((new-key ,new-key))
		      ,(if when
			   `(when ,when
			      (enqueue-map ,new-obj new-key
					   ,(if to to merged-map)))
			   `(enqueue-map ,new-obj new-key 
					 ,(if to to merged-map))))))
	,(when (null to) merged-map))))


;;; ---------- Search ----------

(defstruct armor-tree
  ;; An armor tree is extremely unbalanced, and every left child
  ;; always has a height of 1.
  (left nil)
  (right nil))

(defstruct preliminary
  (forest nil)
  (jewel-sets nil)
  (key 0 :type (unsigned-byte 64)))

(defparameter *satisfy-test-binary* 
  (the (unsigned-byte 64)
       (let ((result (the (unsigned-byte 64) 0)))
         (declare (type (unsigned-byte 64) result))
         (loop for offset from 17 to 62 by 6
            do (setf (ldb (byte 1 offset) result) 1))
         result)))

(defun gen-skill-mask (n)
  "Generate the mask that test for the positivity of the first N
  skills in a skill-key."
  (let ((result (the (unsigned-byte 64) 0)))
    (declare (type (unsigned-byte 64) result))
    (loop 
       for offset from 17 to 62 by 6
       for i below n
       do (setf (ldb (byte 1 offset) result) 1))
    result))


(declaim (inline is-satisfied-skill-key))
(defun is-satisfied-skill-key (key mask)
  (declare (type (unsigned-byte 64) key))
  (declare (type (unsigned-byte 64) mask))
  #f3
  (zerop (logand mask key)))

(defun filter-arsenal-with-jewels (required-effects preliminary-arsenal)
  #f3
  (let ((jewel-combos (create-jewel-combos required-effects))
        (result nil)
        (inv-req-key (encode-skill-sig (mapcar #`,(- (cadr x1)) required-effects))))
    (format t "filtering started ...~%")
    (format t "preliminary: ~a~%" (hash-table-count preliminary-arsenal))
    (loop 
       for armor-key being the hash-keys of preliminary-arsenal
       for forest being the hash-values of preliminary-arsenal
       do (awhen (loop for item in 
                      (gethash (the (signed-byte 64) (hole-part armor-key))
                               jewel-combos)
                    when (is-satisfied-skill-key
                          (encoded-skill-+ inv-req-key
                                           (encoded-skill-+ armor-key
                                                            (jewel-combo-key (car item)))))
                    collect item)
            (push (make-armor-preliminary :forest forest
                                          :jewel-sets it)
                  result)))
    result))


(defun search-foundation (required-effects)
  (let* ((arsenal (list *helms* *cuirasses*
                        *gloves* *cuisses*
                        *sabatons*))
         (clustered-arsenal 
	  (mapcar (lambda (armor-list) 
		    (classify-to-map :across armor-list
				     :key (the (unsigned-byte 64) 
					       (encode-armor individual 
							     required-effects))))
		  arsenal))
         ;; Construct the armor tree (without jewels)
         (preliminary-arsenal
          (reduce (lambda (merged current-part)
		    (merge-maps (current-part merged)
		    		:new-key (the (unsigned-byte 64)
					      (encoded-+ current-part-key
							 merged-key))
		    		:new-obj (make-armor-tree 
					  :left current-part-val
					  :right merged-val)))
                  clustered-arsenal)))
    (loop 
       for key being the hash-keys of preliminary-arsenal
       for forest being the hash-values of preliminary-arsenal
       collect (make-preliminary :forest forest
				 :key key))))


(defstruct split-env
  (hole-query nil)
  (target-id 0)
  (target-points 0)
  (inv-req-key 0)
  (satisfy-mask 0)
  (n 0))

(defun split-forest-at-skill (forest target-id minimum)
  ;; The parameter FOREST is a little bit misleading, as it
  ;; can be a list of armor-trees, or a list of armors (the
  ;; last level). For each armor-tree in FOREST, the left
  ;; child is always a list of armors, and the right child
  ;; can be a list of armors or a forest.
  (if (armor-p (car forest))
      ;; case 1: last level
      (classify-to-map :in forest
		       :key (points-of-skill individual
					     target-id)
		       :when (>= individual-key minimum))
      ;; case 2: middle levels
      (let ((result (make-map)))
	(loop 
	   for tree in forest
	   for left = (classify-to-map :in (armor-tree-left tree)
				       :key (points-of-skill 
					     individual
					     target-id))
	   for right-minimum = (- minimum 
				  (max-map-key left))
	   for right = (split-forest-at-skill (armor-tree-right tree)
					      target-id
					      right-minimum)
	   do (merge-maps (left right)
			  :to result
			  :new-key (+ left-key right-key)
			  :when (>= new-key minimum)
			  :new-obj (make-armor-tree
				    :left left-val
				    :right right-val)))
	result)))

(defun extra-skill-split (prelim env)
  (let* ((n (split-env-n env))
	 (target-points (split-env-target-points env))
	 (prelim-key (the (unsigned-byte 64)
			  (preliminary-key prelim)))
	 (jewel-cands (loop for cand in 
			   (funcall (split-env-hole-query env)
				    (hole-part prelim-key))
			 when (is-satisfied-skill-key 
			       (encoded-skill-+ 
				(keyed-jewel-set-key cand)
				(split-env-inv-req-key env)
				prelim-key)
			       (split-env-satisfy-mask env))
			 collect cand))
	 (minimum (- target-points
		     (loop for cand in jewel-cands
			maximize (decode-skill-sig-at 
				  (keyed-jewel-set-key cand)
				  n)))))
    (when jewel-cands
      (let ((armor-cands (split-forest-at-skill
                          (preliminary-forest prelim)
                          (split-env-target-id env)
                          minimum)))
        (loop 
           for points being the hash-keys of armor-cands
           for forest being the hash-values of armor-cands
           for valid-sets = (loop for item in jewel-cands
                               when (>= (+ points
                                           (decode-skill-sig-at
                                            (keyed-jewel-set-key item)
                                            n))
                                        target-points)
                               append (keyed-jewel-set-set item))
           when valid-sets
           collect (make-preliminary :key (replace-skill-key-at prelim-key
                                                                n
                                                                points)
                                     :forest forest
                                     :jewel-sets valid-sets))))))

(defun make-extra-skill-emitter (input required-effects n)
  (let ((buffer nil)
	(env (make-split-env :hole-query (jewel-query-client 
					  (map-n #`,(nth x1 required-effects) 
						 (1+ n)))
			     :target-id (first (nth n required-effects))
			     :target-points (second (nth n required-effects))
			     :inv-req-key (encode-skill-sig 
					   (mapcar #`,(- (second x1)) 
						   required-effects))
			     :satisfy-mask (gen-skill-mask n)
			     :n n)))
    (emitter-mapcan input (x)
      (emitter-from-list (extra-skill-split x env)))))

(defun search-core (required-effects)
  (let ((foundation (emitter-from-list
                     (search-foundation 
                      (first-n required-effects 
                               *foundation-search-cut-off*)))))
    (reduce (lambda (y x)
              (make-extra-skill-emitter y required-effects x))
            (loop 
               for i from *foundation-search-cut-off* 
               below (length required-effects)
               collect i)
            :initial-value foundation)))

(defun emitter-from-tree (tree)
  (emitter-merge 
      (circular-emitter (armor-tree-left tree))
      (emitter-from-forest (armor-tree-right tree))
      (x y)
    (cons x y)))

(defun emitter-from-forest (forest)
  (if (armor-p (car forest))
      ;; if forest is actually an armor list.
      (emitter-mapcar (emitter-from-list forest) (x)
        (list x))
      ;; otherwise, real forest (list of trees).
      (emitter-mapcan (emitter-from-list forest) (x)
        (emitter-from-tree x))))

(defun make-armor-set-emitter (input)
  (emitter-mapcan input (x)
    (emitter-mapcar 
        (emitter-from-forest (preliminary-forest x)) 
        (armor-list)
      (list armor-list
            (preliminary-jewel-sets x)
            (preliminary-key x)))))

;;; ---------- Debug Utility ----------

(defmacro armor-forest-navigate (tree &rest nav)
  (reduce (lambda (y x) (case x
			  (< `(armor-tree-left ,y))
			  (> `(armor-tree-right ,y))
			  (t `(nth ,x ,y))))
	  nav
	  :initial-value tree))

(defun stringify-effect (effect)
  (concatenate 'string 
               (skill-system-name (aref *skill-systems* 
                                        (car effect)))
               (format nil "~a~a" 
                       (if (> (second effect) 0) "+" "")
                       (second effect))))

(defun print-armor (item)
  (format t "[~a~a~a] ~a  ~{~a ~}~%" 
          (if (< 0 (armor-holes item)) "O" "-")
          (if (< 1 (armor-holes item)) "O" "-")
          (if (< 2 (armor-holes item)) "O" "-")
          (armor-name item)
          (loop for effect in (armor-effects item)
             collect (stringify-effect effect))))

(defun print-jewel (item)
  (format t "([~a~a~a] ~a ~{~a ~})~%"
          (if (< 0 (jewel-holes item)) "O" "x")
          (if (< 1 (jewel-holes item)) "O" "x")
          (if (< 2 (jewel-holes item)) "O" "x")
          (jewel-name item)
          (loop for effect in (jewel-effects item)
             collect (stringify-effect effect))))

(defun print-armor-set (armor-set)
  (let ((all-effects))
    (labels ((add-armor-effects (item)
               (loop for effect in (armor-effects item)
                  do (if (getf all-effects (first effect))
                         (incf (getf all-effects (first effect))
                               (second effect))
                         (setf (getf all-effects (first effect)) 
                               (second effect)))))
             (add-jewel-effects (item)
               (loop for effect in (jewel-effects item)
                  do (if (getf all-effects (first effect))
                         (incf (getf all-effects (first effect)) 
                               (second effect))
                         (setf (getf all-effects (first effect)) 
                               (second effect))))))
      (loop for item in (first armor-set)
         do 
           (print-armor item)
           (add-armor-effects item))
      (loop for id in (first (second armor-set))
         do 
           (print-jewel (aref *jewels* id))
           (add-jewel-effects (aref *jewels* id)))
      (format t "~{~a~%~}"
              (loop for effect in (group all-effects 2)
                 collect (stringify-effect effect)))
      (decode-sig-full (third armor-set) 3))))
                    
  

  
























