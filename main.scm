#!/bin/sh
#| demonstrates a slightly different way to run a script on UNIX systems
exec csi -ss "$0" "$@"
|#

(use spiffy intarweb http-client regex uri-common json)

(define (->symbol x) (string->symbol (->string x)))

;; because posix-utils is broken, yay
;(use srfi-19)
(define (date-string)
  (with-input-from-pipe "date" read-line)
;  (date->string (time->date (current-time)))
)

(define (json-get json name)
  (cond
   ((and (number? name) (list? json))
    (error "Not handling arrays right now"))
   ((and (or (string? name) (symbol? name)) (vector? json))
    (alist-ref (->string name) (vector->list json)
               (lambda (a b) (equal? (->string a) (->string b)))))
   (else
    (error "Bad arguments" json name))))

(define (json-update json name value)
  (cond
   ((and (number? name) (list? json))
    (error "Not handling arrays right now"))
   ((and (or (string? name) (symbol? name)) (vector? json))
    (list->vector
     (alist-update (->symbol name) value (vector->list json)
                   (lambda (a b) (equal? (->string a) (->string b))))))
   (else
    (error "Bad arguments" json name value))))

(define (json-pp json . args)
  (let ((str (with-input-from-pipe
                 (format "json_pp <<< ~s"
                         (with-output-to-string (lambda () (json-write json))))
               read-string)))
    (apply display str args)))

(define (fix-json json)
  (define (fix-field field)
    (or (and-let* ((value (json-get field 'value)))
          (json-update field 'value (->string value)))
        field))
  (define (fix-attachment attach)
    (or (and-let* ((fields (json-get attach 'fields)))
          (json-update attach 'fields (map fix-field fields)))
        attach))
  (json-update json 'attachments
               (map fix-attachment (json-get json 'attachments))))

(define rewrite-target-host (make-parameter #f))
(define rewrite-target-scheme (make-parameter #f))

(define (read-request-body req)
  (read-string (header-value 'content-length (request-headers req) 0)
               (request-port req)))

(define (main args)
  ;; ugly as sin, I know

  ;; blame intarweb's header handling for being retarded

  (rewrite-target-host (get-environment-variable "REWRITE_TARGET_HOST"))
  (rewrite-target-scheme (->symbol (get-environment-variable "REWRITE_TARGET_SCHEME")))
  (printf "Rewriting host to ~s\n~!" (rewrite-target-host))
  (printf "Rewriting scheme to ~s\n~!" (rewrite-target-scheme))
  (printf "Starting server on port ~a.\n~!" (server-port))
  (flush-output)
  (parameterize
      ((vhost-map
        `((,(glob->regexp "*") .
           ,(lambda (continue)
              (printf "================================================================================\n")
              (printf "~a | Incoming request\n" (date-string))
              (printf "================================================================================\n")
#;
              (printf "~a ~a ~a\n"
                      (date->string (time->date (current-time)))
                      (request-method (current-request))
                      (uri->string (request-uri (current-request))))
              (flush-output)
              (let ((body (read-request-body (current-request))))
                (write-request
                 (update-request
                  (current-request)
                  port: (current-output-port)))
                (display body) (newline)
                (printf "================================================================================\n")
                (printf "~a | Outgoing request\n" (date-string))
                (printf "================================================================================\n")
              (let* ((updated-uri
                      (update-uri
                       (request-uri (current-request))
                       scheme: (rewrite-target-scheme)
                       host: (rewrite-target-host)
                       port: #f))
                     (updated-request
                      (update-request
                       (current-request)
                       uri: updated-uri
                       port: #f
                       headers: (headers
                                 `((host (,(rewrite-target-host) . #f)) .
                                   ,(alist-delete 'content-length
                                                  (alist-delete 'host
                                                                (headers->list (request-headers (current-request)))))))))
                     (rewritten-body
                      (with-output-to-string
                        (lambda ()
                          (json-write (fix-json (with-input-from-string body json-read)))
                          (newline)))))
                (client-software (header-value 'user-agent (request-headers updated-request)))
                (write-request
                 (update-request
                  updated-request
                  port: (current-output-port)))
                (display rewritten-body) (newline)
                (flush-output)
                (call-with-input-request*
                 updated-request
                 rewritten-body
                 (lambda (port response)
                   (flush-output)
                   (let ((response-body
                          (with-input-from-port port read-string)))
                     (printf "================================================================================\n")
                     (printf "~a | Outgoing response\n" (date-string))
                     (printf "================================================================================\n")
                     (write-response
                      (update-response response port: (current-output-port)))
                     (display response-body) (newline)
                     (flush-output)
                     (send-response
                      status: (response-status response)
                      body: response-body
                      headers: (headers->list (response-headers response)))))))))))))
      (start-server)))

#;(

(define data (with-input-from-file "/tmp/doesnt_work_payload.txt" json-read))

(json-pp data)

(json-pp (fix-json data))

)
