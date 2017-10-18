(* Red-black trees. *)

theory RBT_Impl
imports SepAuto "../DataStrs/RBT"
begin

section {* Tree nodes *}

datatype ('a, 'b) rbt_node =
  Node (lsub: "('a, 'b) rbt_node ref option") (cl: color) (key: 'a) (val: 'b) (rsub: "('a, 'b) rbt_node ref option")
setup {* fold add_rewrite_rule @{thms rbt_node.sel} *}
setup {* add_forward_prfstep (equiv_forward_th @{thm rbt_node.simps(1)}) *}

fun color_encode :: "color \<Rightarrow> nat" where
  "color_encode B = 0"
| "color_encode R = 1"

instance color :: heap
  apply (rule heap_class.intro)
  apply (rule countable_classI [of "color_encode"])
  apply (metis color_encode.simps(1) color_encode.simps(2) not_B zero_neq_one)
  ..

fun rbt_node_encode :: "('a::heap, 'b::heap) rbt_node \<Rightarrow> nat" where
  "rbt_node_encode (Node l c k v r) = to_nat (l, c, k, v, r)"

instance rbt_node :: (heap, heap) heap
  apply (rule heap_class.intro)
  apply (rule countable_classI [of "rbt_node_encode"])
  apply (case_tac x, simp_all, case_tac y, simp_all)
  ..

fun btree :: "('a::heap, 'b::heap) rbt \<Rightarrow> ('a, 'b) rbt_node ref option \<Rightarrow> assn" where
  "btree Leaf p = \<up>(p = None)"
| "btree (rbt.Node lt c k v rt) (Some p) = (\<exists>\<^sub>Alp rp. p \<mapsto>\<^sub>r Node lp c k v rp * btree lt lp * btree rt rp)"
| "btree (rbt.Node lt c k v rt) None = false"
setup {* fold add_rewrite_ent_rule @{thms btree.simps} *}

lemma btree_Leaf [forward_ent_shadow]: "btree Leaf p \<Longrightarrow>\<^sub>A \<up>(p = None)" by auto2

lemma btree_Node [forward_ent_shadow]:
  "btree (rbt.Node lt c k v rt) (Some p) \<Longrightarrow>\<^sub>A (\<exists>\<^sub>Alp rp. p \<mapsto>\<^sub>r Node lp c k v rp * btree lt lp * btree rt rp)"
  by auto2

lemma btree_Node_none [forward_ent]: "btree (rbt.Node lt c k v rt) None \<Longrightarrow>\<^sub>A false" by auto2

lemma btree_Leaf_some [forward_ent]: "btree Leaf (Some p) \<Longrightarrow>\<^sub>A false" by auto2

lemma btree_is_some [forward_ent]: "btree (rbt.Node lt c k v rt) q \<Longrightarrow>\<^sub>A true * \<up>(q \<noteq> None)" by auto2

lemma btree_is_not_leaf [forward_ent]: "btree t (Some p) \<Longrightarrow>\<^sub>A true * \<up>(t \<noteq> Leaf)" by auto2

lemma btree_none: "emp \<Longrightarrow>\<^sub>A btree Leaf None" by auto2

lemma btree_constr_ent:
  "p \<mapsto>\<^sub>r Node lp c k v rp * btree lt lp * btree rt rp \<Longrightarrow>\<^sub>A btree (rbt.Node lt c k v rt) (Some p)" by auto2

setup {* fold add_entail_matcher [@{thm btree_none}, @{thm btree_constr_ent}] *}

lemma btree_prec [sep_prec_thms]:
  "h \<Turnstile> btree t p * F1 \<Longrightarrow> h \<Turnstile> btree t' p * F2 \<Longrightarrow> t = t'"
@proof @induct t arbitrary p t' F1 F2 @qed

setup {* fold del_prfstep_thm @{thms btree.simps} *}

type_synonym ('a, 'b) btree = "('a, 'b) rbt_node ref option"

section {* Operations *}

subsection {* Basic operations *}

definition tree_empty :: "('a, 'b) btree Heap" where
  "tree_empty \<equiv> return None"
declare tree_empty_def [sep_proc_defs]

lemma tree_empty_rule [hoare_triple]:
  "<emp> tree_empty <btree Leaf>" by auto2
declare tree_empty_def [sep_proc_defs del]

definition tree_is_empty :: "('a, 'b) btree \<Rightarrow> bool Heap" where
  "tree_is_empty b \<equiv> return (b = None)"
declare tree_is_empty_def [sep_proc_defs]

lemma tree_is_empty_rule:
  "<btree t b> tree_is_empty b <\<lambda>r. btree t b * \<up>(r \<longleftrightarrow> t = Leaf)>" by auto2
declare tree_is_empty_def [sep_proc_defs del]

definition btree_constr :: "('a::heap, 'b::heap) btree \<Rightarrow> color \<Rightarrow> 'a \<Rightarrow> 'b \<Rightarrow> ('a, 'b) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "btree_constr lp c k v rp = do { p \<leftarrow> ref (Node lp c k v rp); return (Some p) }"
declare btree_constr_def [sep_proc_defs]

lemma btree_constr_rule [hoare_triple, resolve]:
  "<btree lt lp * btree rt rp> btree_constr lp c k v rp <btree (rbt.Node lt c k v rt)>" by auto2
declare btree_constr_def [sep_proc_defs del]

definition set_color :: "color \<Rightarrow> ('a::heap, 'b::heap) btree \<Rightarrow> unit Heap" where
  "set_color c p = (case p of
    None \<Rightarrow> raise ''set_color''
  | Some pp \<Rightarrow> do {
      t \<leftarrow> !pp;
      pp := Node (lsub t) c (key t) (val t) (rsub t)
    })"
declare set_color_def [sep_proc_defs]

lemma set_color_rule [hoare_triple]:
  "<btree (rbt.Node a c x v b) p>
   set_color c' p
   <\<lambda>_. btree (rbt.Node a c' x v b) p>" by auto2
declare set_color_def [sep_proc_defs del]

definition get_color :: "('a::heap, 'b::heap) btree \<Rightarrow> color Heap" where
  "get_color p = (case p of
     None \<Rightarrow> return B
   | Some pp \<Rightarrow> do {
       t \<leftarrow> !pp;
       return (cl t)
     })"
declare get_color_def [sep_proc_defs]

lemma get_color_heap_preserving [heap_presv_thms]:
  "heap_preserving (get_color p)"
@proof @case "p = None" @qed

lemma get_color_rule [hoare_triple_direct]:
  "<btree t p> get_color p <\<lambda>r. btree t p * \<up>(r = rbt.cl t)>"
@proof @case "t = Leaf" @qed
declare get_color_def [sep_proc_defs del]

definition paint :: "color \<Rightarrow> ('a::heap, 'b::heap) btree \<Rightarrow> unit Heap" where
  "paint c p = (case p of
    None \<Rightarrow> return ()
  | Some pp \<Rightarrow> do {
     t \<leftarrow> !pp;
     pp := Node (lsub t) c (key t) (val t) (rsub t)
   })"
declare paint_def [sep_proc_defs]
  
lemma paint_rule [hoare_triple]:
  "<btree t p>
   paint c p
   <\<lambda>_. btree (RBT.paint c t) p>"
@proof @case "t = Leaf" @qed
declare paint_def [sep_proc_defs del]

subsection {* Rotation *}

definition btree_rotate_l :: "('a::heap, 'b::heap) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "btree_rotate_l p = (case p of
    None \<Rightarrow> raise ''Empty btree''
  | Some pp \<Rightarrow> do {
     t \<leftarrow> !pp;
     (case rsub t of
        None \<Rightarrow> raise ''Empty rsub''
      | Some rp \<Rightarrow> do {
          rt \<leftarrow> !rp;
          pp := Node (lsub t) (cl t) (key t) (val t) (lsub rt);
          rp := Node p (cl rt) (key rt) (val rt) (rsub rt);
          return (rsub t) })})"
declare btree_rotate_l_def [sep_proc_defs]

lemma btree_rotate_l_rule [hoare_triple]:
  "<btree (rbt.Node a c1 x v (rbt.Node b c2 y w c)) p>
   btree_rotate_l p
   <btree (rbt.Node (rbt.Node a c1 x v b) c2 y w c)>" by auto2
declare btree_rotate_l_def [sep_proc_defs del]

definition btree_rotate_r :: "('a::heap, 'b::heap) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "btree_rotate_r p = (case p of
    None \<Rightarrow> raise ''Empty btree''
  | Some pp \<Rightarrow> do {
     t \<leftarrow> !pp;
     (case lsub t of
        None \<Rightarrow> raise ''Empty lsub''
      | Some lp \<Rightarrow> do {
          lt \<leftarrow> !lp;
          pp := Node (rsub lt) (cl t) (key t) (val t) (rsub t);
          lp := Node (lsub lt) (cl lt) (key lt) (val lt) p;
          return (lsub t) })})"
declare btree_rotate_r_def [sep_proc_defs]

lemma btree_rotate_r_rule [hoare_triple]:
  "<btree (rbt.Node (rbt.Node a c1 x v b) c2 y w c) p>
   btree_rotate_r p
   <btree (rbt.Node a c1 x v (rbt.Node b c2 y w c))>" by auto2
declare btree_rotate_r_def [sep_proc_defs del]

subsection {* Balance *}

definition btree_balanceR :: "('a::heap, 'b::heap) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "btree_balanceR p = (case p of None \<Rightarrow> return None | Some pp \<Rightarrow> do {
     t \<leftarrow> !pp;
     cl_r \<leftarrow> get_color (rsub t);
     if cl_r = R then do {
       rt \<leftarrow> !(the (rsub t));
       cl_lr \<leftarrow> get_color (lsub rt);
       cl_rr \<leftarrow> get_color (rsub rt);
       if cl_lr = R then do {
         rp' \<leftarrow> btree_rotate_r (rsub t);
         pp := Node (lsub t) (cl t) (key t) (val t) rp';
         p' \<leftarrow> btree_rotate_l p;
         t' \<leftarrow> !(the p');
         set_color B (rsub t');
         return p'
       } else if cl_rr = R then do {
         p' \<leftarrow> btree_rotate_l p;
         t' \<leftarrow> !(the p');
         set_color B (rsub t');
         return p'
        } else return p }
     else return p})"
declare btree_balanceR_def [sep_proc_defs]

setup {* add_rewrite_rule @{thm balanceR_def} *}
lemma balanceR_to_fun [hoare_triple]:
  "<btree (rbt.Node l B k v r) p>
   btree_balanceR p
   <btree (balanceR l k v r)>" by auto2
setup {* del_prfstep_thm @{thm balanceR_def} *}
declare btree_balanceR_def [sep_proc_defs del]

definition btree_balance :: "('a::heap, 'b::heap) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "btree_balance p = (case p of None \<Rightarrow> return None | Some pp \<Rightarrow> do {
     t \<leftarrow> !pp;
     cl_l \<leftarrow> get_color (lsub t);
     if cl_l = R then do {
       lt \<leftarrow> !(the (lsub t));
       cl_rl \<leftarrow> get_color (rsub lt);
       cl_ll \<leftarrow> get_color (lsub lt);
       if cl_ll = R then do {
         p' \<leftarrow> btree_rotate_r p;
         t' \<leftarrow> !(the p');
         set_color B (lsub t');
         return p' }
       else if cl_rl = R then do {
         lp' \<leftarrow> btree_rotate_l (lsub t);
         pp := Node lp' (cl t) (key t) (val t) (rsub t);
         p' \<leftarrow> btree_rotate_r p;
         t' \<leftarrow> !(the p');
         set_color B (lsub t');
         return p'
       } else btree_balanceR p }
     else do {
       p' \<leftarrow> btree_balanceR p;
       return p'}})"
declare btree_balance_def [sep_proc_defs]

setup {* add_rewrite_rule @{thm balance_def} *}
lemma balance_to_fun [hoare_triple]:
  "<btree (rbt.Node l B k v r) p>
   btree_balance p
   <btree (balance l k v r)>" by auto2
setup {* del_prfstep_thm @{thm balance_def} *}
declare btree_balance_def [sep_proc_defs del]

subsection {* Insertion *}

partial_function (heap) rbt_ins ::
  "'a::{heap,ord} \<Rightarrow> 'b::heap \<Rightarrow> ('a, 'b) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "rbt_ins k v p = (case p of
     None \<Rightarrow> btree_constr None R k v None
   | Some pp \<Rightarrow> do {
      t \<leftarrow> !pp;
      (if cl t = B then
        (if k = key t then do {
           pp := Node (lsub t) (cl t) k v (rsub t);
           return (Some pp) }
         else if k < key t then do {
           q \<leftarrow> rbt_ins k v (lsub t);
           pp := Node q (cl t) (key t) (val t) (rsub t);
           btree_balance p }
         else do {
           q \<leftarrow> rbt_ins k v (rsub t);
           pp := Node (lsub t) (cl t) (key t) (val t) q;
           btree_balance p })
       else
        (if k = key t then do {
           pp := Node (lsub t) (cl t) k v (rsub t);
           return (Some pp) }
         else if k < key t then do {
           q \<leftarrow> rbt_ins k v (lsub t);
           pp := Node q (cl t) (key t) (val t) (rsub t);
           return (Some pp) }
         else do {
           q \<leftarrow> rbt_ins k v (rsub t);
           pp := Node (lsub t) (cl t) (key t) (val t) q;
           return (Some pp) }))})"
declare rbt_ins.simps [sep_proc_defs]

lemma rbt_ins_to_fun [hoare_triple]:
  "<btree t p>
   rbt_ins k v p
   <btree (ins k v t)>"
@proof @induct t arbitrary p @qed
declare rbt_ins.simps [sep_proc_defs del]

definition rbt_insert :: "'a::{heap,ord} \<Rightarrow> 'b::heap \<Rightarrow> ('a, 'b) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "rbt_insert k v p = do {
    p' \<leftarrow> rbt_ins k v p;
    paint B p';
    return p' }"
declare rbt_insert_def [sep_proc_defs]
  
lemma rbt_insert_to_fun [hoare_triple]:
  "<btree t p>
   rbt_insert k v p
   <btree (RBT.rbt_insert k v t)>" by auto2
declare rbt_insert_def [sep_proc_defs del]

subsection {* Search *}

partial_function (heap) rbt_search ::
  "'a::{heap,linorder} \<Rightarrow> ('a, 'b::heap) btree \<Rightarrow> 'b option Heap" where
  "rbt_search x b = (case b of
     None \<Rightarrow> return None
   | Some p \<Rightarrow> do {
      t \<leftarrow> !p;
      (if x = key t then return (Some (val t))
       else if x < key t then rbt_search x (lsub t)
       else rbt_search x (rsub t)) })"
declare rbt_search.simps [sep_proc_defs]

lemma btree_search_correct [hoare_triple]:
  "<btree t b * \<up>(rbt_sorted t)>
   rbt_search x b
   <\<lambda>r. btree t b * \<up>(r = RBT.rbt_search t x)>"
@proof @induct t arbitrary b @qed
declare rbt_search.simps [sep_proc_defs del]
  
subsection {* Delete *}
  
definition btree_balL :: "('a::heap, 'b::heap) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "btree_balL p = (case p of
     None \<Rightarrow> return None
   | Some pp \<Rightarrow> do {
      t \<leftarrow> !pp;
      cl_l \<leftarrow> get_color (lsub t);
      if cl_l = R then do {
        set_color B (lsub t);  (* case 1 *)
        return p}
      else case rsub t of
        None \<Rightarrow> return p  (* case 2 *)
      | Some rp \<Rightarrow> do {  
         rt \<leftarrow> !rp;
         if cl rt = B then do {
           set_color R (rsub t);  (* case 3 *)
           set_color B p;
           btree_balance p}
         else case lsub rt of
           None \<Rightarrow> return p  (* case 4 *)
         | Some lrp \<Rightarrow> do {
            lrt \<leftarrow> !lrp;
            if cl lrt = B then do {
              set_color R (lsub rt);  (* case 5 *)
              paint R (rsub rt);
              set_color B (rsub t); 
              rp' \<leftarrow> btree_rotate_r (rsub t);
              pp := Node (lsub t) (cl t) (key t) (val t) rp';
              p' \<leftarrow> btree_rotate_l p;
              t' \<leftarrow> !(the p');
              set_color B (lsub t');
              rp'' \<leftarrow> btree_balance (rsub t');
              the p' := Node (lsub t') (cl t') (key t') (val t') rp'';
              return p'}
            else return p}}})"
declare btree_balL_def [sep_proc_defs]

setup {* add_rewrite_rule @{thm balL_def} *}
lemma balL_to_fun [hoare_triple]:
  "<btree (rbt.Node l R k v r) p>
   btree_balL p
   <btree (balL l k v r)>" by auto2
setup {* del_prfstep_thm @{thm balL_def} *}
declare btree_balL_def [sep_proc_defs del]

definition btree_balR :: "('a::heap, 'b::heap) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "btree_balR p = (case p of
     None \<Rightarrow> return None
   | Some pp \<Rightarrow> do {
      t \<leftarrow> !pp;
      cl_r \<leftarrow> get_color (rsub t);
      if cl_r = R then do {
        set_color B (rsub t);  (* case 1 *)
        return p}
      else case lsub t of
        None \<Rightarrow> return p  (* case 2 *)
      | Some lp \<Rightarrow> do {  
         lt \<leftarrow> !lp;
         if cl lt = B then do {
           set_color R (lsub t);  (* case 3 *)
           set_color B p;
           btree_balance p}
         else case rsub lt of
           None \<Rightarrow> return p  (* case 4 *)
         | Some rlp \<Rightarrow> do {
            rlt \<leftarrow> !rlp;
            if cl rlt = B then do {
              set_color R (rsub lt);  (* case 5 *)
              paint R (lsub lt);
              set_color B (lsub t); 
              lp' \<leftarrow> btree_rotate_l (lsub t);
              pp := Node lp' (cl t) (key t) (val t) (rsub t);
              p' \<leftarrow> btree_rotate_r p;
              t' \<leftarrow> !(the p');
              set_color B (rsub t');
              lp'' \<leftarrow> btree_balance (lsub t');
              the p' := Node lp'' (cl t') (key t') (val t') (rsub t');
              return p'}
            else return p}}})"
declare btree_balR_def [sep_proc_defs]

setup {* add_rewrite_rule @{thm balR_def} *}
lemma balR_to_fun [hoare_triple]:
  "<btree (rbt.Node l R k v r) p>
   btree_balR p
   <btree (balR l k v r)>" by auto2
setup {* del_prfstep_thm @{thm balR_def} *}
declare btree_balR_def [sep_proc_defs del]

partial_function (heap) btree_combine ::
  "('a::heap, 'b::heap) btree \<Rightarrow> ('a, 'b) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "btree_combine lp rp =
   (if lp = None then return rp
    else if rp = None then return lp
    else do {
      lt \<leftarrow> !(the lp);
      rt \<leftarrow> !(the rp);
      if cl lt = R then
        if cl rt = R then do {
          tmp \<leftarrow> btree_combine (rsub lt) (lsub rt);
          cl_tm \<leftarrow> get_color tmp;
          if cl_tm = R then do {
            tmt \<leftarrow> !(the tmp);
            the lp := Node (lsub lt) R (key lt) (val lt) (lsub tmt);
            the rp := Node (rsub tmt) R (key rt) (val rt) (rsub rt);
            the tmp := Node lp R (key tmt) (val tmt) rp;
            return tmp}
          else do {
            the rp := Node tmp R (key rt) (val rt) (rsub rt);
            the lp := Node (lsub lt) R (key lt) (val lt) rp;
            return lp}}
        else do {
          tmp \<leftarrow> btree_combine (rsub lt) rp;
          the lp := Node (lsub lt) R (key lt) (val lt) tmp;
          return lp}
      else if cl rt = B then do {
        tmp \<leftarrow> btree_combine (rsub lt) (lsub rt);
        cl_tm \<leftarrow> get_color tmp;
        if cl_tm = R then do {
          tmt \<leftarrow> !(the tmp);
          the lp := Node (lsub lt) B (key lt) (val lt) (lsub tmt);
          the rp := Node (rsub tmt) B (key rt) (val rt) (rsub rt);
          the tmp := Node lp R (key tmt) (val tmt) rp;
          return tmp}
        else do {
          the rp := Node tmp B (key rt) (val rt) (rsub rt);
          the lp := Node (lsub lt) R (key lt) (val lt) rp;
          btree_balL lp}}
      else do {
        tmp \<leftarrow> btree_combine lp (lsub rt);
        the rp := Node tmp R (key rt) (val rt) (rsub rt);
        return rp}})"
declare btree_combine.simps [sep_proc_defs]

setup {* fold add_rewrite_rule @{thms combine.simps} *}
lemma combine_to_fun [hoare_triple]:
  "<btree lt lp * btree rt rp>
   btree_combine lp rp
   <btree (combine lt rt)>"
@proof @fun_induct "combine lt rt" arbitrary lp rp @qed
setup {* fold del_prfstep_thm @{thms combine.simps} *}
declare combine.simps [sep_proc_defs del]

partial_function (heap) rbt_del ::
  "'a::{heap,linorder} \<Rightarrow> ('a, 'b::heap) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "rbt_del x p = (case p of
     None \<Rightarrow> return None
   | Some pp \<Rightarrow> do {
      t \<leftarrow> !pp;
      (if x = key t then btree_combine (lsub t) (rsub t)
       else if x < key t then case lsub t of
         None \<Rightarrow> do {
           set_color R p;
           return p}
       | Some lp \<Rightarrow> do {
           lt \<leftarrow> !lp;
           if cl lt = B then do {
             q \<leftarrow> rbt_del x (lsub t);
             pp := Node q R (key t) (val t) (rsub t);
             btree_balL p }
           else do {
             q \<leftarrow> rbt_del x (lsub t);
             pp := Node q R (key t) (val t) (rsub t);
             return p }}
       else case rsub t of
         None \<Rightarrow> do {
           set_color R p;
           return p}
       | Some rp \<Rightarrow> do {
           rt \<leftarrow> !rp;
           if cl rt = B then do {
             q \<leftarrow> rbt_del x (rsub t);
             pp := Node (lsub t) R (key t) (val t) q;
             btree_balR p }
           else do {
             q \<leftarrow> rbt_del x (rsub t);
             pp := Node (lsub t) R (key t) (val t) q;
             return p }})})"
declare rbt_del.simps [sep_proc_defs]

lemma rbt_del_to_fun [hoare_triple]:
  "<btree t p>
   rbt_del x p
   <btree (del x t)>\<^sub>t"
@proof @induct t arbitrary p @qed
declare rbt_del.simps [sep_proc_defs del]

definition rbt_delete :: "'a::{heap,linorder} \<Rightarrow> ('a, 'b::heap) btree \<Rightarrow> ('a, 'b) btree Heap" where
  "rbt_delete k p = do {
    p' \<leftarrow> rbt_del k p;
    paint B p';
    return p'}"
declare rbt_delete_def [sep_proc_defs]
  
lemma rbt_delete_to_fun [hoare_triple]:
  "<btree t p>
   rbt_delete k p
   <btree (RBT.delete k t)>\<^sub>t" by auto2
declare rbt_delete_def [sep_proc_defs del]

section {* Outer interface *}

definition rbt_map_assn :: "('a, 'b) map \<Rightarrow> ('a::{heap,linorder}, 'b::heap) rbt_node ref option \<Rightarrow> assn" where
  "rbt_map_assn M p = (\<exists>\<^sub>At. btree t p * \<up>(is_rbt t) * \<up>(rbt_sorted t) * \<up>(M = rbt_map t))"
setup {* add_rewrite_ent_rule @{thm rbt_map_assn_def} *}

theorem rbt_empty_rule [hoare_triple]:
  "<emp> tree_empty <rbt_map_assn empty_map>" by auto2

theorem rbt_insert_rule [hoare_triple]:
  "<rbt_map_assn M b> rbt_insert k v b <rbt_map_assn (M {k \<rightarrow> v})>" by auto2

theorem rbt_search [hoare_triple]:
  "<rbt_map_assn M b> rbt_search x b <\<lambda>r. rbt_map_assn M b * \<up>(r = M\<langle>x\<rangle>)>" by auto2

theorem rbt_delete_rule [hoare_triple]:
  "<rbt_map_assn M b> rbt_delete k b <rbt_map_assn (delete_map k M)>\<^sub>t" by auto2

end