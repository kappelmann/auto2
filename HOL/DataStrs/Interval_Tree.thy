theory Interval_Tree
imports Lists_Ex
begin
  
definition max3 :: "('a::ord) \<Rightarrow> 'a \<Rightarrow> 'a \<Rightarrow> 'a" where [rewrite]:
  "max3 a b c = max a (max b c)"

section {* Definition of interval *}

datatype 'a interval = Interval (low: 'a) (high: 'a)
setup {* add_rewrite_rule_back @{thm interval.collapse} *}
setup {* add_rewrite_rule @{thm interval.case} *}
setup {* fold add_rewrite_rule @{thms interval.sel} *}

instantiation interval :: (linorder) linorder begin

definition less: "(a < b) = (low a < low b | (low a = low b \<and> high a < high b))"
definition less_eq: "(a \<le> b) = (low a < low b | (low a = low b \<and> high a \<le> high b))"

instance proof
  fix x y z :: "'a interval"
  show a: "(x < y) = (x \<le> y \<and> \<not> y \<le> x)"
    using less local.less_eq by force
  show b: "x \<le> x"
    by (simp add: local.less_eq)
  show c: "x \<le> y \<Longrightarrow> y \<le> z \<Longrightarrow> x \<le> z"
    by (smt Interval_Tree.less_eq dual_order.trans less_trans)
  show d: "x \<le> y \<Longrightarrow> y \<le> x \<Longrightarrow> x = y"
    using Interval_Tree.less_eq a interval.expand less by fastforce
  show e: "x \<le> y \<or> y \<le> x"
    by (meson Interval_Tree.less_eq leI not_less_iff_gr_or_eq)
qed end

definition is_interval :: "('a::linorder) interval \<Rightarrow> bool" where [rewrite]:
  "is_interval it \<longleftrightarrow> (low it \<le> high it)"
setup {* add_property_const @{term is_interval} *}

definition is_overlap :: "nat interval \<Rightarrow> nat interval \<Rightarrow> bool" where [rewrite]:
  "is_overlap x y \<longleftrightarrow> (high x \<ge> low y \<or> high y \<ge> low x)"

section {* Definition of an interval tree *}

datatype interval_tree =
   Tip
 | Node (lsub: interval_tree) (val: "nat interval") (tmax: nat) (rsub: interval_tree)
where
  "tmax Tip = 0"

setup {* add_resolve_prfstep @{thm interval_tree.distinct(2)} *}
setup {* add_forward_prfstep (equiv_forward_th (@{thm interval_tree.simps(1)})) *}
setup {* fold add_rewrite_rule @{thms interval_tree.sel} *}
setup {* add_forward_prfstep_cond @{thm interval_tree.collapse} [with_cond "?tree \<noteq> Node ?l ?k ?v ?r"] *}
setup {* add_var_induct_rule @{thm interval_tree.induct} *}

section {* Inorder traversal, and set of elements of a tree *}

fun in_traverse :: "interval_tree \<Rightarrow> nat interval list" where
  "in_traverse Tip = []"
| "in_traverse (Node l it m r) = (in_traverse l) @ [it] @ (in_traverse r)"
setup {* fold add_rewrite_rule @{thms in_traverse.simps} *}

fun tree_set :: "interval_tree \<Rightarrow> nat interval set" where
  "tree_set Tip = {}"
| "tree_set (Node l it m r) = {it} \<union> tree_set l \<union> tree_set r"
setup {* fold add_rewrite_rule @{thms tree_set.simps} *}

fun tree_sorted :: "interval_tree \<Rightarrow> bool" where
  "tree_sorted Tip = True"
| "tree_sorted (Node l it m r) = ((\<forall>x\<in>tree_set l. x < it) \<and> (\<forall>x\<in>tree_set r. it < x)
                                   \<and> tree_sorted l \<and> tree_sorted r)"
setup {* add_property_const @{term tree_sorted} *}
setup {* fold add_rewrite_rule @{thms tree_sorted.simps} *}

lemma tree_sorted_lr [forward]:
  "tree_sorted (Node l it m r) \<Longrightarrow> tree_sorted l \<and> tree_sorted r" by auto2

lemma inorder_preserve_set [rewrite_back]:
  "set (in_traverse t) = tree_set t"
@proof @induct t @qed

lemma inorder_sorted [rewrite_back]:
  "strict_sorted (in_traverse t) \<longleftrightarrow> tree_sorted t"
@proof @induct t @qed

(* Use definition in terms of in_traverse from now on. *)
setup {* fold del_prfstep_thm (@{thms tree_set.simps} @ @{thms tree_sorted.simps}) *}

section {* Invariant on the maximum *}

fun tree_max_inv :: "interval_tree \<Rightarrow> bool" where
  "tree_max_inv Tip = True"
| "tree_max_inv (Node l it m r) \<longleftrightarrow> (tree_max_inv l \<and> tree_max_inv r \<and> m = max3 (high it) (tmax l) (tmax r))"
setup {* add_property_const @{term tree_max_inv} *}
setup {* fold add_rewrite_rule @{thms tree_max_inv.simps} *}

lemma tree_max_is_max [resolve]:
  "tree_max_inv t \<Longrightarrow> it \<in> tree_set t \<Longrightarrow> high it \<le> tmax t"
@proof @induct t @qed

lemma tmax_exists [backward]:
  "tree_max_inv t \<Longrightarrow> t \<noteq> Tip \<Longrightarrow> \<exists>p\<in>tree_set t. high p = tmax t"
@proof @induct t @with
  @subgoal "t = Node l it m r"
    @case "l = Tip" @with @case "r = Tip" @end
    @case "r = Tip"
  @endgoal @end
@qed

section {* Condition on the values *}

fun tree_interval_inv :: "interval_tree \<Rightarrow> bool" where
  "tree_interval_inv Tip = True"
| "tree_interval_inv (Node l it m r) = (is_interval it \<and> tree_interval_inv l \<and> tree_interval_inv r)"
setup {* add_property_const @{term tree_interval_inv} *}
setup {* fold add_rewrite_rule @{thms tree_interval_inv.simps} *}

lemma tree_interval_inv_def' [rewrite]:
  "tree_interval_inv t \<longleftrightarrow> (\<forall>p\<in>tree_set t. is_interval p)"
@proof @induct t @qed

definition is_interval_tree :: "interval_tree \<Rightarrow> bool" where [rewrite]:
  "is_interval_tree t \<longleftrightarrow> (tree_sorted t \<and> tree_max_inv t \<and> tree_interval_inv t)"
setup {* add_property_const @{term is_interval_tree} *}

section {* Rotation on trees *}

definition rotateL :: "interval_tree \<Rightarrow> interval_tree" where [rewrite]:
  "rotateL t =
    (if t = Tip then t else if rsub t = Tip then t else
     let rt = rsub t;
         ml = max3 (high (val t)) (tmax (lsub t)) (tmax (lsub rt));
         m' = max3 (high (val (rsub t))) ml (tmax (rsub rt)) in
     Node (Node (lsub t) (val t) ml (lsub rt)) (val rt) m' (rsub rt))"

lemma rotateL_in_trav [rewrite]: "in_traverse (rotateL t) = in_traverse t" by auto2

lemma rotateL_set [rewrite]: "tree_set (rotateL t) = tree_set t" by auto2

lemma rotateL_max_inv [forward]: "tree_max_inv t \<Longrightarrow> tree_max_inv (rotateL t)" by auto2

lemma rotateL_all_inv [forward]: "is_interval_tree t \<Longrightarrow> is_interval_tree (rotateL t)" by auto2

definition rotateR :: "interval_tree \<Rightarrow> interval_tree" where [rewrite]:
  "rotateR t =
    (if t = Tip then t else if lsub t = Tip then t else
     let lt = lsub t;
         mr = max3 (high (val t)) (tmax (rsub lt)) (tmax (rsub t));
         m' = max3 (high (val lt)) (tmax (lsub lt)) mr in
     Node (lsub lt) (val lt) m' (Node (rsub lt) (val t) mr (rsub t)))"

lemma rotateR_in_trav [rewrite]: "in_traverse (rotateR t) = in_traverse t" by auto2

lemma rotateR_set [rewrite]: "tree_set (rotateR t) = tree_set t" by auto2

lemma rotateR_max_inv [forward]: "tree_max_inv t \<Longrightarrow> tree_max_inv (rotateR t)" by auto2

lemma rotateR_all_inv [forward]: "is_interval_tree t \<Longrightarrow> is_interval_tree (rotateR t)" by auto2

section {* Insertion on trees *}

fun tree_insert :: "nat interval \<Rightarrow> interval_tree \<Rightarrow> interval_tree" where
  "tree_insert x Tip = Node Tip x (high x) Tip"
| "tree_insert x (Node l y m r) =
    (if x = y then Node l y m r
     else if x < y then
       let l' = tree_insert x l in
           Node l' y (max3 (high y) (tmax l') (tmax r)) r
     else
       let r' = tree_insert x r in
           Node l y (max3 (high y) (tmax l) (tmax r')) r')"
setup {* fold add_rewrite_rule @{thms tree_insert.simps} *}

lemma tree_insert_in_traverse [rewrite]:
  "tree_sorted t \<Longrightarrow> in_traverse (tree_insert x t) = ordered_insert x (in_traverse t)"
@proof @induct t @qed

lemma tree_insert_on_set [rewrite]:
  "tree_sorted t \<Longrightarrow> tree_set (tree_insert it t) = {it} \<union> tree_set t" by auto2

lemma tree_insert_max_inv [forward]:
  "tree_max_inv t \<Longrightarrow> tree_max_inv (tree_insert x t)"
@proof @induct t @qed

lemma tree_insert_all_inv [forward]:
  "is_interval_tree t \<Longrightarrow> is_interval it \<Longrightarrow> is_interval_tree (tree_insert it t)" by auto2

section {* Deletion on trees *}

fun del_min :: "interval_tree \<Rightarrow> nat interval \<times> interval_tree" where
  "del_min Tip = undefined"
| "del_min (Node lt v m rt) =
   (if lt = Tip then (v, rt) else
    let lt' = snd (del_min lt) in
    (fst (del_min lt), Node lt' v (max3 (high v) (tmax lt') (tmax rt)) rt))"
setup {* add_rewrite_rule @{thm del_min.simps(2)} *}
setup {* register_wellform_data ("del_min t", ["t \<noteq> Tip"]) *}

lemma delete_min_del_hd:
  "t \<noteq> Tip \<Longrightarrow> fst (del_min t) # in_traverse (snd (del_min t)) = in_traverse t"
@proof @induct t @qed
setup {* add_forward_prfstep_cond @{thm delete_min_del_hd} [with_term "in_traverse (snd (del_min ?t))"] *}

lemma delete_min_max_inv:
  "tree_max_inv t \<Longrightarrow> t \<noteq> Tip \<Longrightarrow> tree_max_inv (snd (del_min t))"
@proof @induct t @qed
setup {* add_forward_prfstep_cond @{thm delete_min_max_inv} [with_term "snd (del_min ?t)"] *}

lemma delete_min_on_set:
  "t \<noteq> Tip \<Longrightarrow> {fst (del_min t)} \<union> tree_set (snd (del_min t)) = tree_set t" by auto2
setup {* add_forward_prfstep_cond @{thm delete_min_on_set} [with_term "tree_set (snd (del_min ?t))"] *}

lemma delete_min_interval_inv:
  "tree_interval_inv t \<Longrightarrow> t \<noteq> Tip \<Longrightarrow> tree_interval_inv (snd (del_min t))" by auto2
setup {* add_forward_prfstep_cond @{thm delete_min_interval_inv} [with_term "snd (del_min ?t)"] *}

lemma delete_min_all_inv:
  "is_interval_tree t \<Longrightarrow> t \<noteq> Tip \<Longrightarrow> is_interval_tree (snd (del_min t))" by auto2
setup {* add_forward_prfstep_cond @{thm delete_min_all_inv} [with_term "snd (del_min ?t)"] *}

fun delete_elt_tree :: "interval_tree \<Rightarrow> interval_tree" where
  "delete_elt_tree Tip = undefined"
| "delete_elt_tree (Node lt x m rt) =
    (if lt = Tip then rt else if rt = Tip then lt else
     let x' = fst (del_min rt);
         rt' = snd (del_min rt);
         m' = max3 (high x') (tmax lt) (tmax rt') in
       Node lt (fst (del_min rt)) m' rt')"
setup {* add_rewrite_rule @{thm delete_elt_tree.simps(2)} *}

lemma delete_elt_in_traverse [rewrite]:
  "in_traverse (delete_elt_tree (Node lt x m rt)) = in_traverse lt @ in_traverse rt" by auto2

lemma delete_elt_max_inv:
  "tree_max_inv t \<Longrightarrow> t \<noteq> Tip \<Longrightarrow> tree_max_inv (delete_elt_tree t)" by auto2
setup {* add_forward_prfstep_cond @{thm delete_elt_max_inv} [with_term "delete_elt_tree ?t"] *}

lemma delete_elt_on_set [rewrite]:
  "t \<noteq> Tip \<Longrightarrow> tree_set (delete_elt_tree (Node lt x m rt)) = tree_set lt \<union> tree_set rt" by auto2

lemma delete_elt_interval_inv:
  "tree_interval_inv t \<Longrightarrow> t \<noteq> Tip \<Longrightarrow> tree_interval_inv (delete_elt_tree t)" by auto2
setup {* add_forward_prfstep_cond @{thm delete_elt_interval_inv} [with_term "delete_elt_tree ?t"] *}

lemma delete_elt_all_inv:
  "is_interval_tree t \<Longrightarrow> t \<noteq> Tip \<Longrightarrow> is_interval_tree (delete_elt_tree t)" by auto2

fun tree_delete :: "nat interval \<Rightarrow> interval_tree \<Rightarrow> interval_tree" where
  "tree_delete x Tip = Tip"
| "tree_delete x (Node l y m r) =
    (if x = y then delete_elt_tree (Node l y m r)
     else if x < y then
       let l' = tree_delete x l;
           m' = max3 (high y) (tmax l') (tmax r) in Node l' y m' r
     else
       let r' = tree_delete x r;
           m' = max3 (high y) (tmax l) (tmax r') in Node l y m' r')"
setup {* fold add_rewrite_rule @{thms tree_delete.simps} *}

lemma tree_delete_in_traverse [rewrite]:
  "tree_sorted t \<Longrightarrow> in_traverse (tree_delete x t) = remove_elt_list x (in_traverse t)"
@proof @induct t @qed

lemma tree_delete_max_inv [forward]:
  "tree_max_inv t \<Longrightarrow> tree_max_inv (tree_delete x t)"
@proof @induct t @qed
    
lemma tree_delete_all_inv [forward]:
  "is_interval_tree t \<Longrightarrow> is_interval_tree (tree_delete x t)" by auto2

lemma tree_delete_on_set [rewrite]:
  "tree_sorted t \<Longrightarrow> tree_set (tree_delete x t) = tree_set t - {x}" by auto2

section {* Search on interval trees *}

fun tree_search :: "interval_tree \<Rightarrow> nat interval \<Rightarrow> bool" where
  "tree_search Tip x = False"
| "tree_search (Node l y m r) x =
   (if is_overlap x y then True
    else if l \<noteq> Tip \<and> tmax l \<ge> low x then tree_search l x
    else tree_search r x)"
setup {* fold add_rewrite_rule @{thms tree_search.simps} *}

lemma tree_search_correct [rewrite]:
  "is_interval_tree t \<Longrightarrow> is_interval it \<Longrightarrow> tree_search t it \<longleftrightarrow> (\<exists>p\<in>tree_set t. is_overlap it p)"
@proof @induct t @qed

end
