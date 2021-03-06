(*
  File: fol_induct.ML
  Author: Bohua Zhan

  Proof language for induction.
*)

signature SCRIPT_INDUCT_DATA =
sig
  val add_induct_data: string -> thm -> theory -> theory
  val delete_induct_data: string -> thm -> theory -> theory
  val add_induct_data_with_prem: string -> term * thm -> theory -> theory
  val lookup_induct_data: string -> theory -> term -> thm option
  val induct_cmd: string * string * string option -> Proof.state -> Proof.state
  val strong_induct_cmd: string * string list -> Proof.state -> Proof.state
end;

structure ScriptInduct_Data : SCRIPT_INDUCT_DATA =
struct

(* Each induction rule is placed under the pattern for its
   precondition.
 *)
structure Data = Theory_Data (
  type T = ((term * thm) list) Symtab.table;
  val empty = Symtab.empty;
  val extend = I;
  val merge = Symtab.merge_list (eq_fst (op =))
)

fun add_induct_data_with_prem str (t, th) thy =
    let
      (* First remove all induction rules for the given string and term. *)
      val prev_data = (Symtab.lookup_list (Data.get thy) str)
                          |> filter (fn (t', _) => t' aconv t)
      fun print_remove (_, th) =
          writeln ("Removing induction rule " ^
                   (th |> Thm.prop_of |> Syntax.string_of_term_global thy))
      val _ = map print_remove prev_data
      val _ = writeln ("Add induction rule for premise " ^
                       (Syntax.string_of_term_global thy t))
    in
      thy |> Data.map (Symtab.remove_list (fn ((t, _), (t', _)) => t aconv t')
                                          (str, (t, th)))
          |> Data.map (Symtab.cons_list (str, (t, th)))
    end

fun add_induct_data str th =
    add_induct_data_with_prem str (Thm.prems_of th |> hd |> dest_Trueprop, th)

fun delete_induct_data str th =
    Data.map (Symtab.remove_list
                  (fn ((_, th), (_, th')) => Thm.eq_thm_prop (th, th'))
                  (str, (Term.dummy, th)))

fun lookup_induct_data str thy t =
    let
      val data = Symtab.lookup_list (Data.get thy) str
      fun match_data (pat, th) =
          let
            val inst = Pattern.first_order_match thy (pat, t) fo_init
          in
            SOME (Util.subst_thm_thy thy inst th)
          end
          handle Pattern.MATCH => NONE
    in
      get_first match_data data
    end

fun induct_cmd (s, t, u) state =
    let
      val {context = ctxt, ...} = Proof.goal state
      val thy = Proof_Context.theory_of ctxt
      val (prem, goal) = the_pair (Syntax.read_terms ctxt [s, t])

      (* Obtain the induction theorem *)
      val ind_th = the (lookup_induct_data "script_induct" thy prem)
                   handle Option.Option => error "induct: cannot find theorem."

      val concl = concl_of' ind_th
      val (P, vars) = Term.strip_comb concl
      val _ = assert (Term.is_Var P) "induct: P is not schematic variable."
      val P_inst = fold Term.lambda (rev vars) goal
      val inst = Util.update_env (("P", 0), P_inst) fo_init
      val ind_th = Util.subst_thm_thy thy inst ind_th

      (* Obtain list of assumptions *)
      val (_, (As, _)) = ctxt |> Auto2_State.get_subgoal
                              |> Util.strip_meta_horn
      val cAs = map (Thm.cterm_of ctxt) As


      fun retrieve_pat t =
          let
            val t = dest_Trueprop t
            val (vars, (_, C)) = UtilLogic.strip_obj_horn t
            val pat_vars = map (fn t => let val (x, T) = dest_Free t in
                                          Var ((x,0), T)
                                        end) vars
          in
            Term.subst_atomic (vars ~~ pat_vars) C
          end

      val prem = hd (Thm.prems_of ind_th)
      val ind_prems = tl (Thm.prems_of ind_th)
      val pats = prem :: map retrieve_pat ind_prems

      val ind_goals =
          ind_th |> Thm.prems_of
                 |> map (fn t => Logic.list_implies (As, t))
                 |> map (Thm.cterm_of ctxt)
                 |> map (UtilLogic.to_meta_conv ctxt)

      fun solve_eq eq =
          let
            val th = Auto2_Outer.auto2_solve ctxt (Thm.rhs_of eq)
          in
            Thm.equal_elim (meta_sym eq) th
          end
    in
      if is_none u then
        let
          val ths = (map solve_eq ind_goals)
                        |> map Util.send_all_to_hyps
          val ind_concl = (ths MRS ind_th)
                              |> fold Thm.implies_intr (rev cAs)
          val after_qed = Auto2_Outer.have_after_qed ctxt ind_concl
        in
          state |> Proof.map_contexts (Auto2_State.map_head_th after_qed)
        end
      else
        let
          fun after_qed ths prop =
              let
                val ths' = (ind_goals ~~ ths)
                               |> map (fn (eq, th) =>
                                          Thm.equal_elim (meta_sym eq) th)
                               |> map Util.send_all_to_hyps
                val ind_concl = (ths' MRS ind_th)
                                    |> fold Thm.implies_intr (rev cAs)
              in
                Auto2_Outer.have_after_qed ctxt ind_concl prop
              end

          val new_frame =
              Auto2_State.multiple_frame (pats ~~ map Thm.rhs_of ind_goals,
                                          SOME ([], after_qed))
        in
          state |> Proof.map_contexts (Auto2_State.push_head new_frame)
        end
    end

val _ =
  Outer_Syntax.command @{command_keyword "@induct"} "apply induction"
    (Parse.term -- Parse.term -- Scan.option @{keyword "@with"} >>
        (fn ((s, t), u) =>
            Toplevel.proof (fn state => induct_cmd (s, t, u) state)))

fun strong_induct_cmd (s, t) state =
    let
      val {context = ctxt, ...} = Proof.goal state
      val thy = Proof_Context.theory_of ctxt
      val prem = s |> Syntax.read_term ctxt

      val arbitraries = map (Syntax.read_term ctxt) t

      val prop = Auto2_State.get_selected ctxt
      val (vars, (As, C)) = prop |> Thm.prems_of |> the_single
                                 |> Util.strip_meta_horn

      val ind_th = the (lookup_induct_data "strong_induct" thy prem)
                   handle Option.Option => error "strong induct: ind_th not found."
      val n_conds = Thm.nprems_of ind_th - 1

      val (var_P, var) = ind_th |> Thm.concl_of |> dest_Trueprop
                                |> Term.dest_comb

      val use_As = As |> map dest_Trueprop
      val P = (UtilLogic.list_obj_horn (arbitraries, (use_As, dest_Trueprop C)))
                  |> Util.lambda_abstract var

      val inst = Pattern.match thy (var_P, P) fo_init
      val ind_th = ind_th |> Util.subst_thm ctxt inst
                          |> apply_to_thm (Util.skip_n_conv n_conds (
                                Conv.binop_conv (UtilLogic.to_meta_conv ctxt)))

      val ind_goals = ind_th |> Thm.prems_of |> take n_conds
                             |> map (fn t => Logic.list_implies (As, t))
                             |> map (Thm.cterm_of ctxt)

      val ths = (map (Auto2_Outer.auto2_solve ctxt) ind_goals)
                    |> map Util.send_all_to_hyps

      val ind_th = ind_th |> fold Thm.elim_implies ths
      val prems = ind_th |> Drule.cprems_of
      val ind_th = ind_th |> Util.send_all_to_hyps
                          |> fold Thm.implies_intr (rev prems)

      val assum = hd (Drule.cprems_of ind_th)
      val ind_th =
          ind_th |> Util.send_first_to_hyps
                 |> fold Thm.forall_elim (map (Thm.cterm_of ctxt) arbitraries)
                 |> fold Thm.forall_intr (map (Thm.cterm_of ctxt) vars)
                 |> Thm.implies_intr assum

      val t' = case Thm.prop_of ind_th of
                   imp $ A $ B => imp $ Util.rename_abs_term [var] A $ B
                 | _ => error "strong_induct_cmd"
      val ind_th = ind_th |> Thm.renamed_prop t'

      val prop = prop |> Auto2_Outer.refine_subgoal_th ind_th
    in
      state |> Proof.map_contexts (Auto2_State.map_head_th (K prop))
    end

val arbitrary =
    Scan.option (@{keyword "arbitrary"} |-- Scan.repeat Parse.term)

val _ =
  Outer_Syntax.command @{command_keyword "@strong_induct"}
    "apply strong induction"
    (Parse.term -- arbitrary >> (fn (s, t) =>
        Toplevel.proof (fn state => strong_induct_cmd (s, these t) state)))

end  (* structure ScriptInduct_Data *)

val add_script_induct_data = ScriptInduct_Data.add_induct_data "script_induct"
val delete_script_induct_data = ScriptInduct_Data.delete_induct_data "script_induct"
val add_strong_induct_data = ScriptInduct_Data.add_induct_data "strong_induct"
