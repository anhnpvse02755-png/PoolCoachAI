// Danh sách trường Directus của từng collection, dùng chung cho đồng bộ trong
// app và helper máy chủ. Các file đồng bộ cũ `export` lại để import cũ vẫn chạy.

const poolMatchRemoteFields =
    'id,user_created,game_type,player_name,opponent_name,target_racks,'
    'rack_winners,shots,cue_id,started_at,completed_at,updated_at,is_deleted,'
    'tournament_id,round_label';
const timerSessionRemoteFields =
    'id,user_created,date,duration_sec,cat,cat_ext,cue_id';
const scheduleSlotRemoteFields =
    'id,user_created,day,time,label,cat,cat_ext,cat_ext_at,updated_at,is_deleted';
const cueEquipmentRemoteFields =
    'id,user_created,name,type,weight_grams,shaft_brand,tip_diameter_mm,'
    'tip_brand,tip_hardness,butt_brand,skill_categories,skill_categories_ext,last_tip_maintenance,tip_maintenance_due_date,'
    'updated_at,is_deleted';
const remoteTestFields = 'id,started_at,completed_at,cancelled_at,table_size,'
    'exam_i_score,exam_ii_version,exam_ii_score,total_score,result_rank';
const remoteResultFields = 'id,test_id,drill_id,attempts,score,recorded_at';
const drillLogRemoteFields =
    'id,drill_id,date,score,attempts,notes,duration_sec';

// Preferences thông báo (một dòng mỗi tài khoản, id = id người dùng) và nhật
// ký đã gửi/đã hiện của thông báo đẩy từ máy chủ.
const notificationSettingsRemoteFields =
    'id,recommendation,maintenance,schedule,streak,prefs_updated_at,'
    'last_seen_cat,last_seen_drill_id,last_seen_at,timezone';
const pushDeliveryRemoteFields =
    'id,device,notification_id,kind,key,title,body,at,shown_at';
