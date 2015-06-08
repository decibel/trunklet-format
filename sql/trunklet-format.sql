SELECT trunklet.template_language__add(
  language_name := 'format'
  , parameter_type := 'jsonb'
  , template_type := 'text'
  , process_function_options := 'LANGUAGE plpgsql'
  , process_function_body := $process_body$
DECLARE
  c_param CONSTANT jsonb := parameters::jsonb;
  v_return text;
BEGIN
  IF jsonb_typeof(c_param) <> 'object' THEN
    RAISE EXCEPTION 'parameter must be a JSON object, not %', jsonb_typeof(c_param)
      USING DETAIL = 'parameters = ' || c_param
    ;
  END IF;

  -- Sanity-check parameters
  DECLARE
    paramater_name text;
    value text;
    v_type text;
  BEGIN
    FOR paramater_name, value IN SELECT * FROM jsonb_each( c_param )
    LOOP
      IF paramater_name ~ '%' THEN
        RAISE EXCEPTION 'parameter names may not contain %'
          USING DETAIL = 'parameter ' || paramater_name
        ;
      END IF;

      v_type := jsonb_typeof( c_param->paramater_name );
      IF v_type IN ( 'array', 'object' ) THEN
        RAISE EXCEPTION '% is not supported as a parameter type', v_type
          USING DETAIL = format( $$paramater %s = %s$$, paramater_name, value )
        ;
      END IF;
    END LOOP;
  END;

  /*
   * Look for things to replace
   */
  DECLARE
    c_parse CONSTANT text[] := string_to_array( template::text, '%' );
    c_alen CONSTANT int := array_length( c_parse, 1 );
    v_pos int := 2; -- We handle first element specially
    v_cur text;
    v_first text;
    v_value text;
  BEGIN
    /*
     * We have to special-case the first element because we know it must be
     * plain text with no paramaters.
     */
    v_return := c_parse[1];
    WHILE v_pos <= c_alen LOOP
      v_cur := c_parse[v_pos];
      --RAISE WARNING 'v_pos = %, v_cur = %', v_pos, v_cur;

      /*
       * The %% escape gives us an empty v_cur.
       */
      IF v_cur = '' THEN
        v_return := v_return || '%';
        CONTINUE;
      END IF;

      /*
       * Since we don't allow % in a parameter name, we know that v_cur is the name of a parameter.
       */
      IF (c_param->v_cur) IS NULL THEN
        RAISE EXCEPTION 'parameter % not found', v_cur
          USING DETAIL = 'parse position ' || v_pos
        ;
      END IF;
      v_value := CASE WHEN jsonb_typeof(c_param->v_cur) = 'null' THEN NULL ELSE c_param->>v_cur END;
      v_pos := v_pos + 1;
      IF v_pos > c_alen THEN
        RAISE EXCEPTION 'Reached end of template while processing parameters'
          USING HINT = 'Parameters must match the format "%parameter_name%T" where T is s, I or L.'
        ;
      END IF;
      v_cur := c_parse[v_pos];

      -- This is where to insert support for other format option handling
      v_first := substr( v_cur, 1, 1 );
      --RAISE WARNING 'v_pos = %, v_cur = %, v_first = %', v_pos, v_cur, v_first;
      IF v_first NOT IN ( 's', 'I', 'L' ) THEN
        RAISE EXCEPTION 'Unexpected character % trailing parameter name', v_first
          USING DETAIL = format( 'parse position %s, parameter name %s', v_pos, c_parse[v_pos - 1] )
        ;
      END IF;

      v_return := v_return || format( '%' || v_first, v_value ) || substr( v_cur, 2 );
      v_pos := v_pos + 1;
    END LOOP;
  END;

  RETURN v_return;
END
$process_body$
  , extract_parameters_options := 'LANGUAGE plpgsql'
  , extract_parameters_body := $extract_body$
BEGIN
    RETURN NULL::jsonb;
END
$extract_body$
);

-- vi: expandtab ts=2 sw=2
