(local {: autoload : define} (require :conjure.nfnl.module))
(local a (autoload :conjure.aniseed.core))
(local client (autoload :conjure.client))
(local config (autoload :conjure.config))
(local log (autoload :conjure.log))
(local mapping (autoload :conjure.mapping))
(local stdio (autoload :conjure.remote.stdio))
(local str (autoload :conjure.aniseed.string))
(local ts (autoload :conjure.tree-sitter))

(local M (define :conjure.client.java.stdio))

(config.merge
  {:client
   {:java
    {:stdio
     {:command "jshell -q"
      :prompt-pattern "jshell> "
     }}}})

(when (config.get-in [:mapping :enable_defaults])
  (config.merge
    {:client
     {:java
      {:stdio
       {:mapping {:start "cs"
                  :stop "cS"
                  :interrupt "ei"}}}}}))

(local cfg (config.get-in-fn [:client :java :stdio]))
(local state (client.new-state #(do {:repl nil})))

(set M.buf-suffix ".java")
(set M.comment-prefix "// ")

(fn format-message [msg]
  (->> (str.split msg.out "\n")
       (a.filter #(~= "" $1))))

(fn unbatch [msgs]
  {:out (->> msgs
          (a.map #(or (a.get $1 :out) (a.get $1 :err)))
          (str.join ""))})

(fn with-repl-or-warn [f opts]
  (let [repl (state :repl)]
    (if repl
        (f repl)
        (log.append [(.. M.comment-prefix "No REPL running")
                     (.. M.comment-prefix "Start REPL with "
                         (config.get-in [:mapping :prefix])
                         (cfg [:mapping :start]))]))))
(fn display-repl-status [status]
  ( log.append
    [(.. M.comment-prefix
         (cfg [:command])
         " (" (or status "no status") ")")]
    {:break? true}))

(fn M.start []
  (if (state :repl)
    (log.append [(.. M.comment-prefix "Can't start, REPL is already running.")
                 (.. M.comment-prefix "Stop the REPL with "
                     (config.get-in [:mapping :prefix])
                     (cfg [:mapping :stop]))]
                {:break? true})
    (if (not (pcall #(ts.add-language "java")))
      (log.append [(.. M.comment-prefix "(error) The java client requires a java treesitter parser in order to function.")
                   (.. M.comment-prefix "(error) See https://github.com/nvim-treesitter/nvim-treesitter")
                   (.. M.comment-prefix "(error) for installation instructions.")])
      (a.assoc
        (state) :repl
        (stdio.start
          {:prompt-pattern (cfg [:prompt-pattern])
           :cmd (cfg [:command])

           :on-success
           (fn []
             ;; TODO: add import statements?
             (display-repl-status :started))

           :on-error
           (fn [err]
             (display-repl-status err))

           :on-exit
           (fn [code signal]
             (when (and (= :number (type code)) (> code 0))
               (log.append [(.. M.comment-prefix "process exited with code " code)]))
             (when (and (= :number (type signal)) (> signal 0))
               (log.append [(.. M.comment-prefix "process exited with signal " signal)]))
             (M.stop))

           :on-stray-output
           (fn [msg]
             (log.append (format-message msg)))})))))

;; Probably need to parse with tree-sitter
;; if call a non static method, then we need to add static keyword
;; also need to get methods in call order and evaluate those first
;; Need to run all the import statements too
(fn prep-code [s]
  (if (string.find s "\n")
    (.. s "")
    (.. s "\n")
    ))

(fn M.eval-str [opts]
  (with-repl-or-warn
    (fn [repl]
      (repl.send
        (prep-code opts.code)
        (fn [msgs]
          (let [lines (-> msgs unbatch format-message)]
            (when opts.on-result
              (opts.on-result (a.last lines)))
            (log.append lines)))
        {:batch? true}))))

(fn stop []
  (let [repl (state :repl)]
    (when repl
      (repl.destroy)
      (display-repl-status :stopped)
      (a.assoc (state) :repl nil))))

(fn M.on-exit []
  (M.stop))

(fn M.interrupt []
  (with-repl-or-warn
    (fn [repl]
      (log.append [(.. M.comment-prefix " Sending interrupt signal.")] {:break? true})
      (repl.send-signal :sigint))))

(fn M.on-load []
  ;; Start up REPL only if g.conjure#client_on_load is v:true.
  (when (config.get-in [:client_on_load])
    (M.start)))

(fn M.on-filetype []
  (mapping.buf
    :JavaStart (cfg [:mapping :start])
    #(M.start)
    {:desc "Start the Java REPL"})

  (mapping.buf
    :JavaStop (cfg [:mapping :stop])
    #(M.stop)
    {:desc "Stop the Java REPL"})

  (mapping.buf
    :JavaInterrupt (cfg [:mapping :interrupt])
    #(M.interrupt)
    {:desc "Interrupt the current evaluation"}))

M
