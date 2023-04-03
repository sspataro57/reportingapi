drop function if exists collab.GetActivityIDsFunc;
drop function if exists collab.GetActivityCountFunc;

CREATE OR REPLACE FUNCTION collab.GetActivityIDsFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL
)
RETURNS TABLE (ret_id uuid)
AS $$
BEGIN
    RETURN QUERY SELECT collab.activities.id
                 FROM collab.activities
                 WHERE portal_id = p_portal_id::uuid
                   AND (p_status IS NULL OR status = p_status)
                   AND (p_start_time IS NULL OR start_time > p_start_time - interval '1 second')
                   AND (p_end_time IS NULL OR start_time < p_end_time + interval '1 second')
                   AND (p_focus_areas IS NULL OR focus_areas @> p_focus_areas)
                   AND (p_program_id IS NULL OR id IN (SELECT activity_id FROM collab.activity_to_programs WHERE program_id = ANY (CAST(p_program_id AS uuid[]))))
                   AND (
                       p_longitude IS NULL AND p_latitude IS NULL
                       OR (
                           (p_virtual_location = true AND (NOT EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id) OR EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true)))
                           OR (p_virtual_location = false AND NOT EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true) AND ST_DistanceSphere(ST_MakePoint(longitude, latitude), ST_MakePoint(p_longitude, p_latitude)) * 0.000621371 < p_distance)
                       )
                   )
                   AND (p_virtual_location IS NULL OR (p_virtual_location = true AND EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true)) OR (p_virtual_location = false AND NOT EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true)));
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION collab.GetActivityCountFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL
)
RETURNS TABLE (portalid varchar, count bigint)
AS $$
BEGIN
    RETURN QUERY SELECT portal_id::varchar, count(id)
                 FROM collab.activities
                 WHERE id IN (SELECT ret_id FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas, p_program_id, p_longitude, p_latitude, p_distance, p_virtual_location))
                 GROUP BY portal_id;
END;
$$ LANGUAGE plpgsql;



GRANT EXECUTE ON FUNCTION collab.GetActivityIDsFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean
) TO api_readonly;

GRANT EXECUTE ON FUNCTION collab.GetActivityCountFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean
) TO api_readonly;

COMMENT ON FUNCTION collab.GetActivityCountFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean
) IS E'@name GetActivityCountFunc';

COMMENT ON FUNCTION collab.GetActivityIDsFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean
) IS E'@omit: "create,update,delete"';