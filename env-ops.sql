-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('env-ops.sql', '$Id');

--	Wicci Project
--	ref features requiring type environment contexts

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * Operators

-- oftd !!!
CREATE OR REPLACE FUNCTION oftd_ref_env_crefs_text_op(
	regprocedure, refs[], refs[], refs, refs, env_refs, crefs
) RETURNS text AS 'spx.so', 'oftd_ref_env_crefs_etc_text_op'
LANGUAGE c;

CREATE OR REPLACE
FUNCTION ref_env_text_op(refs, env_refs) RETURNS text
AS 'spx.so', 'call_text_method'  LANGUAGE c;

CREATE OR REPLACE FUNCTION try_show_ref_env(
	refs, env_refs=env_nil(), ref_tags=NULL
) RETURNS text AS $$
	SELECT ref_env_text_op($1, $2) FROM typed_object_methods
	WHERE tag_ = COALESCE($3, ref_tag($1))
	AND operation_ = this('ref_env_text_op(refs, env_refs)')
$$ LANGUAGE sql;

SELECT declare_op_fallback(
	'ref_env_text_op(refs, env_refs)',
	'ref_text_op(refs)'
);

CREATE OR REPLACE
FUNCTION ref_env_crefs_text_op(refs, env_refs, crefs) RETURNS text
AS 'spx.so', 'ref_env_crefs_etc_text_op' LANGUAGE c;

CREATE OR REPLACE FUNCTION try_show_ref_env_crefs(
	refs, env_refs=env_nil(), crefs=crefs_nil(), ref_tags=NULL
) RETURNS text AS $$
	SELECT ref_env_crefs_text_op($1, $2, $3)
	FROM typed_object_methods
	WHERE tag_ = COALESCE($4, ref_tag($1))
	AND operation_ = this('ref_env_crefs_text_op(refs, env_refs, crefs)')
$$ LANGUAGE sql;

SELECT declare_op_fallback(
	'ref_env_crefs_text_op(refs, env_refs, crefs)',
	'ref_env_text_op(refs, env_refs)'
);

CREATE OR REPLACE
FUNCTION show_ref(refs, text=NULL) RETURNS text AS $$
	SELECT COALESCE($2 || ': ', '') || COALESCE(
		try_show_ref($1, _tag),
		try_show_ref_env($1, env_nil(), _tag),
		try_show_ref_env_crefs($1, env_nil(), crefs_nil(), _tag),
		ref_textout($1)
	) FROM ref_tag($1) _tag;
$$ LANGUAGE sql;
