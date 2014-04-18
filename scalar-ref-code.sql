-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('scalar-ref-code.sql', '$Id');

--	Wicci Project
--	Common code for scalar ref types

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Dependencies

-- * env_best

CREATE OR REPLACE
FUNCTION env_best_value(env_refs, refs, name_refs)
RETURNS refs AS $$
	SELECT COALESCE(
		env_obj_feature_value($1, $2, $3),
		env_name_value($1, $3)
	)
$$ LANGUAGE sql;
COMMENT ON
FUNCTION env_best_value(env_refs, refs, name_refs)
IS 'get the best value of a feature for this object as follows:
	first priority: value intended for me in environment
	second priority: default value in environment
';

CREATE OR REPLACE
FUNCTION env_best_text_value(env_refs, refs, name_refs, text)
RETURNS text AS $$
	SELECT COALESCE(
		ref_text_op(env_best_value($1, $2, $3)),
			$4
	)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION env_best(
	_outside env_refs, _this refs, name_refs, _inside env_refs,
	_dfalt env_refs = env_nil()
) RETURNS refs AS $$
	SELECT COALESCE(
		env_obj_feature_value(inside, $2, $3),
		env_obj_feature_value(outside, $2, $3),
		env_name_value(inside, $3),
		env_name_value(outside, $3),
		env_name_value(dfalt, $3)
	)
	FROM
		COALESCE($1, env_nil()) outside,
		COALESCE($4, env_nil()) inside,
		COALESCE($5, env_nil()) dfalt
$$ LANGUAGE sql;
COMMENT ON FUNCTION env_best(
	outside env_refs, this refs, name_refs, inside env_refs, dfalt env_refs
) IS 'get the best value of a feature for this object as follows:
	first priority: association to me in my internal environment - pinned!
	second priority: association to me in environment passed in
	third priority: default value in my internal environment
	fourth priority: default value in environment passed in
	last priority: default value in default environment, if any
';

CREATE OR REPLACE FUNCTION try_env_best_text(
	outside env_refs, this refs, name_refs, inside env_refs, dfalt env_refs
) RETURNS text AS $$
	SELECT CASE WHEN best IS NULL THEN NULL
	ELSE ref_text_op(best)
	END FROM env_best($1, $2, $3, $4, $5) best
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION env_best_text(
	outside env_refs, this refs, name_refs, inside env_refs, dfalt env_refs
) RETURNS text AS $$
	SELECT non_null(
		try_env_best_text($1, $2, $3, $4, $5),
		'env_best_text(env_refs, refs, name_refs, env_refs, env_refs)'
	)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION try_env_best_text(
	outside env_refs, this refs, name_refs, inside env_refs,
	text = NULL
) RETURNS text AS $$
	SELECT CASE WHEN best IS NULL THEN $5
	ELSE ref_text_op(best)
	END FROM env_best($1, $2, $3, $4) best
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION env_best_text(
	outside env_refs, this refs, name_refs, inside env_refs,
	text = NULL
) RETURNS text AS $$
	SELECT non_null(
		try_env_best_text($1, $2, $3, $4, $5),
		'env_best_text(env_refs, refs, name_refs, env_refs, text)',
		ref_textout($2)
	)
$$ LANGUAGE sql;
