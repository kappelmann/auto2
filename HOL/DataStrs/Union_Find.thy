theory Union_Find
imports Partial_Equiv_Rel
begin

section {* Representing a partial equivalence relation using rep_of array *}
  
function (domintros) rep_of where
  "rep_of l i = (if l ! i = i then i else rep_of l (l ! i))" by auto

setup {* register_wellform_data ("rep_of l i", ["i < length l"]) *}
setup {* add_backward_prfstep @{thm rep_of.domintros} *}
setup {* add_rewrite_rule @{thm rep_of.psimps} *}
setup {* add_prop_induct_rule @{thm rep_of.pinduct} *}

definition ufa_invar :: "nat list \<Rightarrow> bool" where [rewrite]:
  "ufa_invar l = (\<forall>i<length l. rep_of_dom (l, i) \<and> l ! i < length l)"
setup {* add_property_const @{term ufa_invar} *}

lemma ufa_invarD:
  "ufa_invar l \<Longrightarrow> i < length l \<Longrightarrow> rep_of_dom (l, i) \<and> l ! i < length l" by auto2
setup {* add_forward_prfstep_cond @{thm ufa_invarD} [with_term "?l ! ?i"] *}
setup {* del_prfstep_thm_eqforward @{thm ufa_invar_def} *}

lemma rep_of_id [rewrite]: "ufa_invar l \<Longrightarrow> i < length l \<Longrightarrow> l ! i = i \<Longrightarrow> rep_of l i = i" by auto2

lemma rep_of_iff [rewrite]:
  "ufa_invar l \<Longrightarrow> i < length l \<Longrightarrow> rep_of l i = (if l ! i = i then i else rep_of l (l ! i))" by auto2

lemma rep_of_min [rewrite]:
  "ufa_invar l \<Longrightarrow> i < length l \<Longrightarrow> l ! (rep_of l i) = rep_of l i"
@proof @prop_induct "rep_of_dom (l, i)" @qed

lemma rep_of_induct:
  "ufa_invar l \<and> i < length l \<Longrightarrow>
   \<forall>i<length l. l ! i = i \<longrightarrow> P l i \<Longrightarrow>
   \<forall>i<length l. l ! i \<noteq> i \<longrightarrow> P l (l ! i) \<longrightarrow> P l i \<Longrightarrow> P l i"
@proof @prop_induct "rep_of_dom (l, i)" @qed
setup {* add_prop_induct_rule @{thm rep_of_induct} *}

lemma rep_of_bound:
  "ufa_invar l \<Longrightarrow> i < length l \<Longrightarrow> rep_of l i < length l"
@proof @prop_induct "ufa_invar l \<and> i < length l" @qed
setup {* add_forward_prfstep_cond @{thm rep_of_bound} [with_term "rep_of ?l ?i"] *}

lemma rep_of_idem [rewrite]:
  "ufa_invar l \<Longrightarrow> i < length l \<Longrightarrow> rep_of l (rep_of l i) = rep_of l i" by auto2

lemma rep_of_idx [rewrite]: 
  "ufa_invar l \<Longrightarrow> i < length l \<Longrightarrow> rep_of l (l ! i) = rep_of l i" by auto2

definition ufa_\<alpha> :: "nat list \<Rightarrow> (nat \<times> nat) set" where [rewrite]:
  "ufa_\<alpha> l = {(x, y). x < length l \<and> y < length l \<and> rep_of l x = rep_of l y}"

lemma ufa_\<alpha>_memI [backward]:
  "x < length l \<Longrightarrow> y < length l \<Longrightarrow> rep_of l x = rep_of l y \<Longrightarrow> (x, y) \<in> ufa_\<alpha> l"
  by (simp add: ufa_\<alpha>_def)
setup {* add_forward_prfstep_cond @{thm ufa_\<alpha>_memI} [with_term "ufa_\<alpha> ?l"] *}
  
lemma ufa_\<alpha>_memD [forward]:
  "(x, y) \<in> ufa_\<alpha> l \<Longrightarrow> x < length l \<and> y < length l \<and> rep_of l x = rep_of l y"
  by (simp add: ufa_\<alpha>_def)
setup {* del_prfstep_thm @{thm ufa_\<alpha>_def} *}

lemma ufa_\<alpha>_equiv [forward]: "part_equiv (ufa_\<alpha> l)" by auto2

lemma ufa_\<alpha>_refl [rewrite]: "(i, i) \<in> ufa_\<alpha> l \<longleftrightarrow> i < length l" by auto2

section {* Operations on rep_of array *}

definition uf_init_rel :: "nat \<Rightarrow> (nat \<times> nat) set" where [rewrite]:
  "uf_init_rel n = ufa_\<alpha> [0..<n]"

lemma ufa_init_invar [resolve]: "ufa_invar [0..<n]" by auto2

lemma ufa_init_correct [rewrite]:
  "(x, y) \<in> uf_init_rel n \<longleftrightarrow> (x = y \<and> x < n)"
@proof @have "ufa_invar [0..<n]" @qed

definition ufa_union :: "nat list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat list" where [rewrite_bidir]:
  "ufa_union l x y = l[rep_of l x := rep_of l y]"
setup {* register_wellform_data ("ufa_union l x y", ["x < length l", "y < length l"]) *}

lemma ufa_union_invar:
  "ufa_invar l \<Longrightarrow> x < length l \<Longrightarrow> y < length l \<Longrightarrow> l' = ufa_union l x y \<Longrightarrow> ufa_invar l'"
@proof
  @have "\<forall>i<length l'. rep_of_dom (l', i) \<and> l' ! i < length l'" @with
    @prop_induct "ufa_invar l \<and> i < length l"
  @end
@qed
setup {* add_forward_prfstep_cond @{thm ufa_union_invar} [with_term "?l'"] *}

lemma ufa_union_aux [rewrite]:
  "ufa_invar l \<Longrightarrow> x < length l \<Longrightarrow> y < length l \<Longrightarrow> l' = ufa_union l x y \<Longrightarrow>
   i < length l' \<Longrightarrow> rep_of l' i = (if rep_of l i = rep_of l x then rep_of l y else rep_of l i)"
@proof @prop_induct "ufa_invar l \<and> i < length l" @qed
  
lemma ufa_union_correct [rewrite]:
  "ufa_invar l \<Longrightarrow> x < length l \<Longrightarrow> y < length l \<Longrightarrow> l' = ufa_union l x y \<Longrightarrow>
   ufa_\<alpha> l' = per_union (ufa_\<alpha> l) x y"
@proof
  @have "\<forall>a b. (a,b) \<in> ufa_\<alpha> l' \<longleftrightarrow> (a,b) \<in> per_union (ufa_\<alpha> l) x y" @with
    @case "(a,b) \<in> ufa_\<alpha> l'" @with
      @case "rep_of l a = rep_of l x"
      @case "rep_of l a = rep_of l y"
    @end
  @end
@qed

definition ufa_compress :: "nat list \<Rightarrow> nat \<Rightarrow> nat list" where [rewrite_bidir]:
  "ufa_compress l x = l[x := rep_of l x]"
setup {* register_wellform_data ("ufa_compress l x", ["x < length l"]) *}

lemma ufa_compress_invar:
  "ufa_invar l \<Longrightarrow> x < length l \<Longrightarrow> l' = ufa_compress l x \<Longrightarrow> ufa_invar l'"
@proof
  @have "\<forall>i<length l'. rep_of_dom (l', i) \<and> l' ! i < length l'" @with
    @prop_induct "ufa_invar l \<and> i < length l"
  @end
@qed
setup {* add_forward_prfstep_cond @{thm ufa_compress_invar} [with_term "?l'"] *}
  
lemma ufa_compress_aux [rewrite]:
  "ufa_invar l \<Longrightarrow> x < length l \<Longrightarrow> l' = ufa_compress l x \<Longrightarrow> i < length l' \<Longrightarrow>
   rep_of l' i = rep_of l i"
@proof @prop_induct "ufa_invar l \<and> i < length l" @qed

lemma ufa_compress_correct [rewrite]:
  "ufa_invar l \<Longrightarrow> x < length l \<Longrightarrow> ufa_\<alpha> (ufa_compress l x) = ufa_\<alpha> l" by auto2

setup {* del_prfstep_thm @{thm rep_of_iff} *}
setup {* del_prfstep_thm @{thm rep_of.psimps} *}

end
