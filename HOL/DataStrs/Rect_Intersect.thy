theory Rect_Intersect
imports Interval_Tree
begin

section {* Definition of rectangles *}

datatype 'a rectangle = Rectangle (xint: "'a interval") (yint: "'a interval")
setup {* add_rewrite_rule_back @{thm rectangle.collapse} *}
setup {* add_rewrite_rule @{thm rectangle.case} *}
setup {* fold add_rewrite_rule @{thms rectangle.sel} *}

definition is_rect :: "('a::linorder) rectangle \<Rightarrow> bool" where [rewrite]:
  "is_rect rect \<longleftrightarrow> is_interval (xint rect) \<and> is_interval (yint rect)"
setup {* add_property_const @{term is_rect} *}

definition is_rect_list :: "('a::linorder) rectangle list \<Rightarrow> bool" where [rewrite]:
  "is_rect_list rects \<longleftrightarrow> (\<forall>i<length rects. is_rect (rects ! i))"
setup {* add_property_const @{term is_rect_list} *}

lemma is_rect_listD: "is_rect_list rects \<Longrightarrow> i < length rects \<Longrightarrow> is_rect (rects ! i)" by auto2
setup {* add_forward_prfstep_cond @{thm is_rect_listD} [with_term "?rects ! ?i"] *}

setup {* del_prfstep_thm_eqforward @{thm is_rect_list_def} *}

definition is_rect_overlap :: "('a::linorder) rectangle \<Rightarrow> ('a::linorder) rectangle \<Rightarrow> bool" where [rewrite]:
  "is_rect_overlap A B \<longleftrightarrow> (is_overlap (xint A) (xint B) \<and> is_overlap (yint A) (yint B))"

definition has_rect_overlap :: "('a::linorder) rectangle list \<Rightarrow> bool" where [rewrite]:
  "has_rect_overlap As \<longleftrightarrow> (\<exists>i<length As. \<exists>j<length As. i \<noteq> j \<and> is_rect_overlap (As ! i) (As ! j))"

section {* INS / DEL operations *}

(* Encode INS as false and DEL as true *)
datatype ('a::linorder) operation = Operation (pos: 'a) (ty: bool) (idx: nat) (int: "'a interval")
setup {* add_rewrite_rule_back @{thm operation.collapse} *}
setup {* add_rewrite_rule @{thm operation.case} *}
setup {* fold add_rewrite_rule @{thms operation.sel} *}
setup {* add_rewrite_rule @{thm operation.simps(1)} *}

instantiation operation :: (linorder) linorder begin

definition less: "(a < b) = (if pos a \<noteq> pos b then pos a < pos b else
                             if ty a \<noteq> ty b then ty a < ty b else
                             if idx a \<noteq> idx b then idx a < idx b else int a < int b)"
definition less_eq: "(a \<le> b) = (if pos a \<noteq> pos b then pos a < pos b else
                                 if ty a \<noteq> ty b then ty a < ty b else
                                 if idx a \<noteq> idx b then idx a < idx b else int a \<le> int b)"

instance proof
  fix x y z :: "'a operation"
  show a: "(x < y) = (x \<le> y \<and> \<not> y \<le> x)"
    using less local.less_eq by force
  show b: "x \<le> x"
    by (simp add: local.less_eq)
  show c: "x \<le> y \<Longrightarrow> y \<le> z \<Longrightarrow> x \<le> z"
    by (smt Rect_Intersect.less Rect_Intersect.less_eq a dual_order.trans less_trans)
  show d: "x \<le> y \<Longrightarrow> y \<le> x \<Longrightarrow> x = y"
    by (metis Rect_Intersect.less Rect_Intersect.less_eq a le_imp_less_or_eq operation.expand)
  show e: "x \<le> y \<or> y \<le> x"
    using local.less_eq by fastforce
qed end

setup {* fold add_rewrite_rule [@{thm less_eq}, @{thm less}] *}

lemma operation_leD [forward]:
  "(a::('a::linorder operation)) \<le> b \<Longrightarrow> pos a \<le> pos b" by auto2

lemma operation_lessI [backward2]:
  "pos a = pos b \<Longrightarrow> ty a < ty b \<Longrightarrow> (a::('a::linorder operation)) < b" by auto2

setup {* fold del_prfstep_thm [@{thm less_eq}, @{thm less}] *}

section {* Set of operations corresponding to a list of rectangles *}

fun ins_op :: "'a rectangle list \<Rightarrow> nat \<Rightarrow> ('a::linorder) operation" where
  "ins_op rects i = Operation (low (yint (rects ! i))) False i (xint (rects ! i))"
setup {* add_rewrite_rule @{thm ins_op.simps} *}

fun del_op :: "'a rectangle list \<Rightarrow> nat \<Rightarrow> ('a::linorder) operation" where
  "del_op rects i = Operation (high (yint (rects ! i))) True i (xint (rects ! i))"
setup {* add_rewrite_rule @{thm del_op.simps} *}

definition ins_ops :: "'a rectangle list \<Rightarrow> ('a::linorder) operation list" where [rewrite]:
  "ins_ops rects = list (\<lambda>i. ins_op rects i) (length rects)"

definition del_ops :: "'a rectangle list \<Rightarrow> ('a::linorder) operation list" where [rewrite]:
  "del_ops rects = list (\<lambda>i. del_op rects i) (length rects)"

definition all_ops :: "'a rectangle list \<Rightarrow> ('a::linorder) operation list" where [rewrite]:
  "all_ops rects = ins_ops rects @ del_ops rects"

lemma ins_ops_distinct [forward]: "distinct (ins_ops rects)"
@proof
  @let "xs = ins_ops rects"
  @have "\<forall>i<length xs. \<forall>j<length xs. i \<noteq> j \<longrightarrow> xs ! i \<noteq> xs ! j"
@qed

lemma del_ops_distinct [forward]: "distinct (del_ops rects)"
@proof
  @let "xs = del_ops rects"
  @have "\<forall>i<length xs. \<forall>j<length xs. i \<noteq> j \<longrightarrow> xs ! i \<noteq> xs ! j"
@qed

lemma set_ins_ops [rewrite]:
  "oper \<in> set (ins_ops rects) \<longleftrightarrow> idx oper < length rects \<and> oper = ins_op rects (idx oper)"
@proof
  @case "oper \<in> set (ins_ops rects)" @with
    @obtain i where "i < length rects" "ins_ops rects ! i = oper" @end
  @case "idx oper < length rects \<and> oper = ins_op rects (idx oper)" @with
    @have "oper = (ins_ops rects) ! (idx oper)" @end
@qed

lemma set_del_ops [rewrite]:
  "oper \<in> set (del_ops rects) \<longleftrightarrow> idx oper < length rects \<and> oper = del_op rects (idx oper)"
@proof
  @case "oper \<in> set (del_ops rects)" @with
    @obtain i where "i < length rects" "del_ops rects ! i = oper" @end
  @case "idx oper < length rects \<and> oper = del_op rects (idx oper)" @with
    @have "oper = (del_ops rects) ! (idx oper)" @end
@qed

lemma all_ops_distinct [forward]: "distinct (all_ops rects)" by auto2

lemma set_all_ops_idx [forward]:
  "oper \<in> set (all_ops rects) \<Longrightarrow> idx oper < length rects" by auto2

lemma set_all_ops_ins [forward]:
  "oper \<in> set (all_ops rects) \<Longrightarrow> \<not> ty oper \<Longrightarrow> oper = ins_op rects (idx oper)" by auto2

lemma set_all_ops_del [forward]:
  "oper \<in> set (all_ops rects) \<Longrightarrow> ty oper \<Longrightarrow> oper = del_op rects (idx oper)" by auto2

lemma ins_in_set_all_ops:
  "i < length rects \<Longrightarrow> ins_op rects i \<in> set (all_ops rects)" by auto2
setup {* add_forward_prfstep_cond @{thm ins_in_set_all_ops} [with_term "ins_op ?rects ?i"] *}

lemma del_in_set_all_ops:
  "i < length rects \<Longrightarrow> del_op rects i \<in> set (all_ops rects)" by auto2
setup {* add_forward_prfstep_cond @{thm del_in_set_all_ops} [with_term "del_op ?rects ?i"] *}

section {* Applying a set of operations *}

definition apply_ops_set :: "'a rectangle list \<Rightarrow> ('a::linorder) operation set \<Rightarrow> nat set" where
  "apply_ops_set rects ops = {i. i < length rects \<and> ins_op rects i \<in> ops \<and> del_op rects i \<notin> ops}"

lemma apply_ops_set_mem [rewrite]:
  "i \<in> apply_ops_set rects ops \<longleftrightarrow> (i < length rects \<and> ins_op rects i \<in> ops \<and> del_op rects i \<notin> ops)"
  using apply_ops_set_def by auto

definition xints_of :: "'a rectangle list \<Rightarrow> nat set \<Rightarrow> ('a::linorder) interval set" where
  "xints_of rect is = (\<lambda>i. xint (rect ! i)) ` is"

lemma xints_of_mem [rewrite]:
  "it \<in> xints_of rect is \<longleftrightarrow> (\<exists>i\<in>is. xint (rect ! i) = it)" using xints_of_def by auto

lemma apply_ops_set_mem2 [forward]:
  "ops = sort (all_ops rects) \<Longrightarrow> k < length ops \<Longrightarrow>
   i \<in> apply_ops_set rects (set (take k ops)) \<Longrightarrow>
   low (yint (rects ! i)) \<le> pos (ops ! k)"
@proof
  @obtain k' where "k' < k" "ops ! k' = ins_op rects i"
  @have "ops ! k' \<le> ops ! k"
@qed

lemma apply_ops_set_mem3 [forward]:
  "ops = sort (all_ops rects) \<Longrightarrow> k < length ops \<Longrightarrow>
   i \<in> apply_ops_set rects (set (take k ops)) \<Longrightarrow>
   high (yint (rects ! i)) \<ge> pos (ops ! k)"
@proof
  @have "set ops = set (all_ops rects)"
  @have "del_op rects i \<notin> set (take k ops)"
  @obtain k' where "k' < length ops" "ops ! k' = del_op rects i"
  @have "k' \<ge> k"
  @have "ops ! k' \<ge> ops ! k"
@qed

definition has_overlap_at_k :: "'a rectangle list \<Rightarrow> ('a::linorder) operation list \<Rightarrow> nat \<Rightarrow> bool" where [rewrite]:
  "has_overlap_at_k rects ops k \<longleftrightarrow> (
    let S = apply_ops_set rects (set (take k ops)) in
      \<not>ty (ops ! k) \<and> has_overlap (xints_of rects S) (int (ops ! k)))"
setup {* register_wellform_data ("has_overlap_at_k rects ops k", ["k < length ops"]) *}

lemma has_overlap_at_k_equiv [forward]:
  "is_rect_list rects \<Longrightarrow> ops = sort (all_ops rects) \<Longrightarrow> k < length ops \<Longrightarrow>
   has_overlap_at_k rects ops k \<Longrightarrow> has_rect_overlap rects"
@proof
  @let "S = apply_ops_set rects (set (take k ops))"
  @have "has_overlap (xints_of rects S) (int (ops ! k))"
  @obtain "xs \<in> xints_of rects S" where "is_overlap xs (int (ops ! k))"
  @obtain "i \<in> S" where "xint (rects ! i) = xs"
  @have "ins_op rects i \<in> set (take k ops)"
  @let "j = idx (ops ! k)"
  @have "ops ! k \<in> set ops"
  @have "ops ! k = ins_op rects j"
  @case "i = j" @with
    @obtain k' where "k' < k" "ops ! k' = ins_op rects i"
    @have "ops ! k = ops ! k'"
  @end
  @have "is_rect_overlap (rects ! i) (rects ! j)"
@qed

lemma has_overlap_at_k_equiv2 [resolve]:
  "is_rect_list rects \<Longrightarrow> ops = sort (all_ops rects) \<Longrightarrow> has_rect_overlap rects \<Longrightarrow>
   \<exists>k<length ops. has_overlap_at_k rects ops k"
@proof
  @obtain i j where "i < length rects" "j < length rects" "i \<noteq> j"
                    "is_rect_overlap (rects ! i) (rects ! j)"
  @have "is_rect_overlap (rects ! j) (rects ! i)"
  @have "set ops = set (all_ops rects)"
  @obtain i1 where "i1 < length ops" "ops ! i1 = ins_op rects i"
  @obtain j1 where "j1 < length ops" "ops ! j1 = ins_op rects j"
  @obtain i2 where "i2 < length ops" "ops ! i2 = del_op rects i"
  @obtain j2 where "j2 < length ops" "ops ! j2 = del_op rects j"
  @case "ins_op rects i < ins_op rects j" @with
    @have "i1 < j1"
    @have "j1 < i2" @with @have "ops ! j1 < ops ! i2" @end
    @case "ops ! i2 \<in> set (take j1 ops)" @with
      @obtain k' where "k' < j1" "ops ! k' = ops ! i2" @end
    @have "has_overlap_at_k rects ops j1"
  @end
  @case "ins_op rects j < ins_op rects i" @with
    @have "j1 < i1"
    @have "i1 < j2" @with @have "ops ! i1 < ops ! j2" @end
    @case "ops ! j2 \<in> set (take i1 ops)" @with
      @obtain k' where "k' < i1" "ops ! k' = ops ! j2" @end
    @have "has_overlap_at_k rects ops i1"
  @end
@qed

definition has_overlap_lst :: "'a rectangle list \<Rightarrow> ('a::linorder) operation list \<Rightarrow> bool" where [rewrite]:
  "has_overlap_lst rects ops = (\<exists>k<length ops. has_overlap_at_k rects ops k)"

lemma has_overlap_equiv [rewrite]:
  "is_rect_list rects \<Longrightarrow> ops = sort (all_ops rects) \<Longrightarrow>
   has_overlap_lst rects ops \<longleftrightarrow> has_rect_overlap rects" by auto2

end
