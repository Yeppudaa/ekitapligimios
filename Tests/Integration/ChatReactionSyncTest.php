<?php
/**
 * Offline integration: load real XF and Siropu implementation files, replacing
 * only storage, routing, templates and unrelated delivery repositories.
 * Never boot a configured XenForo app or connect to its database.
 * Shares the offline boundary harness used by the Android chat validation;
 * this copy executes the iOS helper and exercises the actual visitor cache too.
 */
namespace {
    $xfSourceRoot = getenv('CHAT_SYNC_XF_SOURCE_ROOT') ?: 'C:/xampp/htdocs/ekitapligim/src';
    if (!is_file($xfSourceRoot . '/XF/Repository/ReactionRepository.php')) {
        fwrite(STDERR, "Set CHAT_SYNC_XF_SOURCE_ROOT to a local XenForo source tree.\n");
        exit(2);
    }
    spl_autoload_register(static function ($class) use ($xfSourceRoot) {
        $path = $xfSourceRoot . '/' . str_replace('\\', '/', $class) . '.php';
        if (str_starts_with($class, 'Siropu\\')) $path = $xfSourceRoot . '/addons/' . str_replace('\\', '/', $class) . '.php';
        if (is_file($path)) require_once $path;
    });
    class XF {
        public static $time = 1900000000, $app, $em, $visitor, $extension;
        public static function app(){return self::$app;} public static function em(){return self::$em;}
        public static function db(){return self::$em->getDb();} public static function visitor(){return self::$visitor;}
        public static function options(){return self::$app->options();} public static function extension(){return self::$extension;}
        public static function fire(...$args){} public static function phrase($name,...$args){return $name;}
        public static function repository($name){return self::$em->getRepository($name);}
        public static function extendClass($class){return $class;}
        public static function getClassForAlias($class){return $class;}
        public static function asVisitor($user,$callback){$old=self::$visitor;self::$visitor=$user;try{return $callback();}finally{self::$visitor=$old;}}
        public static function stringToClass($name,$format){if(!str_contains($name,':'))return $name;[$vendor,$short]=explode(':',$name,2);return sprintf($format,$vendor,$short);}
        public static function classToString($name,$format){return $name;}
        public static function logException($error,...$args){throw $error;}
    }
}
namespace XF {
    class App {
        public $actions=[], $alerts=[], $feeds=[], $webhooks=[], $activity=[], $settings;
        public function __construct(){ $this->settings=new \ArrayObject(['siropuChatEnabled'=>true,'siropuChatReactions'=>true,
            'siropuChatCountRoomReactions'=>false,'siropuChatHideMessageContentFromUserGroups'=>[],
            'siropuChatEnabledBBCodes'=>['quote'=>true],'siropuChatThreadMessageMinLength'=>0,
            'defaultStyleId'=>1,'boardUrl'=>'https://example.invalid'],\ArrayObject::ARRAY_AS_PROPS); }
        public function options(){return $this->settings;} public function db(){return \XF::db();}
        public function container($name=null){if($name==='reactions')return [1=>['active'=>true,'reaction_score'=>1],2=>['active'=>true,'reaction_score'=>1],6=>['active'=>true,'reaction_score'=>-1]];return $this;}
        public function create(...$args){return new \stdClass();}
        public function findByContentType($type,$id,$with){if($type!=='siropu_chat_room_message')throw new \RuntimeException('Wrong shared content type');return \XF::em()->find('Siropu\\Chat:Message',$id);}
        public function getContentTypeFieldValue($type,$field){return $type==='siropu_chat_room_message' && $field==='reaction_handler_class' ? 'Siropu\\Chat\\Reaction\\RoomMessage' : null;}
        public function service($name,...$args){if($name==='Siropu\\Chat:Room\\ActionLogger')return new \Siropu\Chat\Service\Room\ActionLogger($this,...$args);throw new \RuntimeException('Unexpected service '.$name);}
        public function templater(){return new class {function addDefaultParam(...$args){}function setStyle(...$args){}function func($name,$args){return json_encode(['counts'=>$args[0]->reactions,'users'=>$args[0]->reaction_users]);}};}
        public function getGlobalTemplateData(){return [];}
        public function stringFormatter(){return new class {function censorText($text){return $text;}function stripBbCode($text,$options=[]){return preg_replace('/\[[^\]]*\]/','',$text);}};}
        public function bbCode(){return new class {function render($text,...$args){return $text;}};}
        public function isAddOnActive(...$args){return true;}
    }
}
namespace XF\Entity {
    class User extends \XF\Mvc\Entity\Entity {
        public static function getStructure(\XF\Mvc\Entity\Structure $s){$s->primaryKey='user_id';$s->shortName='XF:User';$s->table='xf_user';$s->columns=['user_id'=>['type'=>self::UINT],'username'=>['type'=>self::STR],'is_admin'=>['type'=>self::BOOL,'default'=>false],'is_moderator'=>['type'=>self::BOOL,'default'=>false],'is_staff'=>['type'=>self::BOOL,'default'=>false]];return $s;}
        public function hasPermission(...$args){return true;} public function hasNodePermission(...$args){return true;}
        public function isIgnoring($id){return false;} public function canSanctionSiropuChat(){return false;}
        public function canViewSiropuChatRoomArchiveUponJoin(){return true;} public function getSiropuChatRoomJoinTime(...$args){return 0;}
        public function getSiropuChatSetting(...$args){return false;} public function isMemberOf(...$args){return false;}
        public function canUseSiropuChat(){return true;} public function isBannedSiropuChat(){return false;}
        public function isMutedSiropuChat(){return false;} public function isSanctionedSiropuChat(){return false;}
        public function siropuChatGetRoomSanction(...$args){return null;} public function getAvatarUrl(...$args){return '';}
    }
}
namespace Siropu\Chat\Entity {
    class Room extends \XF\Mvc\Entity\Entity {
        public static function getStructure(\XF\Mvc\Entity\Structure $s){$s->primaryKey='room_id';$s->shortName='Siropu\\Chat:Room';$s->table='xf_siropu_chat_room';$s->columns=['room_id'=>['type'=>self::UINT],'room_thread_id'=>['type'=>self::UINT,'default'=>0]];return $s;}
        public function isReadOnly(){return false;} public function isLocked(...$args){return false;}
        public function isJoined(){return true;} public function canJoin(...$args){return true;}
    }
}
namespace Siropu\Chat\Util {
    // The real ActionLogger runs; its filesystem boundary remains in memory.
    class Action {public static function getData(...$args){return \XF::app()->actions;}public static function writeData(array $data=[]){\XF::app()->actions=$data;}}
}
namespace {
    class SyncDb extends \XF\Db\AbstractAdapter {
        public $tables=['xf_reaction_content'=>[],'xf_siropu_chat_message'=>[]], $lastId=100, $updates=0;
        protected function getStatementClass(){return '';} protected function _rawQuery($query){throw new \RuntimeException('Network/SQL disabled');}
        protected function standardizeConfig(array $config){return $config;} public function getConnection(){throw new \RuntimeException('Connection disabled');}
        public function isConnected(){return false;} public function ping(){return false;} public function lastInsertId(){return $this->lastId;}
        public function getServerVersion(){return 'offline';} public function getConnectionStats(){return [];} public function escapeString($str){return addslashes($str);}
        public function getDefaultTableConfig(){return [];} public function beginTransaction(){} public function commit(){} public function rollback(){}
        public function insert($table,array $data,$replace=false,$ignore=false,$duplicate=null){if($table!=='xf_reaction_content')throw new \RuntimeException('Unexpected insert');$data['reaction_content_id']=++$this->lastId;$this->tables[$table][$this->lastId]=$data;return 1;}
        public function update($table,array $data,$where,$params=[],$modifiers='',$order='',$limit=0){if($table!=='xf_siropu_chat_message')throw new \RuntimeException('Unexpected update');preg_match('/message_id\s*=\s*([0-9]+)/',$where,$m);$id=$m[1]??10;$this->tables[$table][$id]=array_replace($this->tables[$table][$id]??[],$data);$this->updates++;return 1;}
        public function delete($table,$where,$params=[],$modifiers='',$order='',$limit=0): int {if($table!=='xf_reaction_content')throw new \RuntimeException('Unexpected delete');preg_match('/reaction_content_id[^0-9]*([0-9]+)/',$where,$m);unset($this->tables[$table][$m[1]]);return 1;}
        public function fetchPairs($query,$params=[]){$counts=[];foreach($this->tables['xf_reaction_content'] as $row)if($row['content_type']===$params[0] && (int)$row['content_id']===(int)$params[1])$counts[$row['reaction_id']]=($counts[$row['reaction_id']]??0)+1;return $counts;}
        public function fetchAll($query,$params=[]){$latest=[];foreach($this->tables['xf_reaction_content'] as $row)if($row['content_type']===$params[0] && (int)$row['content_id']===(int)$params[1])$latest[]=['user_id'=>(int)$row['reaction_user_id'],'username'=>\XF::em()->find('XF:User',$row['reaction_user_id'])->username,'reaction_id'=>(int)$row['reaction_id']];return $latest;}
        public function fetchOne($query,$params=[],$column=0){return null;}
        public function quote($data,$type=null){if(is_array($data))return implode(',',array_map(fn($v)=>$this->quote($v),$data));return is_numeric($data)?(string)$data:"'".$this->escapeString($data)."'";}
    }
    class SyncManager extends \XF\Mvc\Entity\Manager {
        public function find($name,$id,$with=null){$class=$this->getEntityClassName($name);$key=$this->getEntityCacheLookupString((array)$id);if(isset($this->entities[$class][$key]))return $this->entities[$class][$key];$table=$this->getEntityStructure($name)->table;$row=$this->db->tables[$table][$id]??null;return $row?$this->instantiateEntity($name,$row):null;}
        public function getRepository($name){if($name==='XF:Reaction'||$name==='XF\\Repository\\ReactionRepository')return $this->repositories['reaction']??=new \XF\Repository\ReactionRepository($this,'XF:Reaction');return new class {function queueWebhook(...$args){\XF::app()->webhooks[]=$args;}function log(...$args){\XF::app()->activity[]=$args;}function alertFromUser(...$args){\XF::app()->alerts[]=$args;return true;}function fastDeleteAlertsFromUser(...$args){}function publish(...$args){\XF::app()->feeds[]=$args;}function unpublish(...$args){}};}
        public function getFinder($name,$includeDefaultWith=true){return new class($this,$name){private $em,$name,$conditions=[];function __construct($em,$name){$this->em=$em;$this->name=$name;}function where($key,$value=null){if(is_array($key))$this->conditions=array_replace($this->conditions,$key);else $this->conditions[$key]=$value;return $this;}function fetchOne(){foreach($this->em->getDb()->tables['xf_reaction_content'] as $row){foreach($this->conditions as $key=>$value)if((string)$row[$key] !== (string)$value)continue 2;return $this->em->instantiateEntity('XF:ReactionContent',$row);}return null;}};}
        public function getRelation(array $relation,\XF\Mvc\Entity\Entity $entity,$fetchType='current'){
            $name=$relation['entity'];$class=$this->getEntityClassName($name);
            if($class==='XF\\Entity\\User'){$field=$relation['conditions'][0][2];return $this->find($name,$entity->{substr($field,1)});}
            if($class==='Siropu\\Chat\\Entity\\Room')return $this->find($name,$entity->message_room_id);
            if($class==='XF\\Entity\\Reaction')return new class {public $reaction_score=1;};
            if($class==='XF\\Entity\\ReactionContent'){$result=[];foreach($this->db->tables['xf_reaction_content'] as $row)if($row['content_type']===$entity->getEntityContentType() && (int)$row['content_id']===(int)$entity->message_id)$result[$row['reaction_user_id']]=$this->instantiateEntity($name,$row);return $result;}
            throw new \RuntimeException('Unexpected relation '.$name);
        }
    }
    \XF::$extension=new \XF\Extension();\XF::$app=new \XF\App();$db=new SyncDb([]);\XF::$em=$em=new SyncManager($db,new \XF\Mvc\Entity\ValueFormatter(),\XF::$extension);
    $actor=$em->instantiateEntity('XF:User',['user_id'=>1,'username'=>'Android']);$author=$em->instantiateEntity('XF:User',['user_id'=>2,'username'=>'Web']);\XF::$visitor=$actor;
    $em->instantiateEntity('Siropu\\Chat:Room',['room_id'=>1,'room_thread_id'=>0]);
    $message=$em->instantiateEntity('Siropu\\Chat:Message',['message_id'=>10,'message_room_id'=>1,'message_user_id'=>2,'message_username'=>'Web','message_text'=>'Kitap','message_type'=>'chat','message_date'=>1900000000,'reactions'=>'[]','reaction_users'=>'[]','reaction_score'=>0,'message_like_count'=>0]);
    require dirname(__DIR__, 2).'/Backend/IosApi-addon/Service/ChatInteraction.php';
    $repo=$em->getRepository('XF:Reaction');$checks=0;
    function syncCheck($condition,$label){global $checks;if(!$condition)throw new \RuntimeException($label);$checks++;}
    syncCheck($message->getEntityContentType()===\Ekitapligim\IosApi\Service\ChatInteraction::CONTENT_TYPE,'Web and mobile must share actual entity content type');
    foreach([1,2,6,0] as $id){
        $message->getVisitorReactionId();
        $state=\Ekitapligim\IosApi\Service\ChatInteraction::setReaction($repo,$message,$actor,$id);
        syncCheck($state['changed'],'Actual repository must change requested reaction '.$id);
        $persisted=json_decode($db->tables['xf_siropu_chat_message'][10]['reactions'],true);
        syncCheck($persisted===($id?[$id=>1]:[]),'Actual XF handler must persist Siropu reaction cache '.$id);
        syncCheck(isset(\XF::app()->actions['rooms'][1][10]['action']['react']),'Actual Siropu logger must publish a react action '.$id);
        $rendered=json_decode(\XF::app()->actions['rooms'][1][10]['reactions'],true);
        syncCheck($id?($rendered['counts'][$id]??0)===1:\XF::app()->actions['rooms'][1][10]['reactions']==='','Actual logger must publish current reaction HTML '.$id);
        // Permission checks can prime this relation before the repository writes.
        $message->clearCache('Reactions');
        syncCheck((int)$message->getVisitorReactionId()===$id,'Fresh visitor selection must equal saved desired state '.$id);
        $updates=$db->updates;
        $again=\Ekitapligim\IosApi\Service\ChatInteraction::setReaction($repo,$message,$actor,$id);
        syncCheck(!$again['changed'] && $db->updates===$updates,'Retry must not toggle or rewrite reaction '.$id);
    }
    // The web plugin invokes this repository directly. Reading via the iOS
    // entity afterward must see the same selection and count, including removal.
    $repo->reactToContent(2,'siropu_chat_room_message',10,$actor,true);
    $message->clearCache('Reactions');
    syncCheck($message->getVisitorReactionId()===2 && $message->reactions[2]===1,'Web repository write must be visible to iOS');
    $repo->reactToContent(2,'siropu_chat_room_message',10,$actor,true);
    $message->clearCache('Reactions');
    syncCheck((int)$message->getVisitorReactionId()===0 && !$message->reactions,'Web toggle removal must be visible to iOS');
    echo json_encode(['ok'=>true,'checks'=>$checks,'network_requests'=>0,'db_connections'=>0,
        'actual_classes'=>['XF\\Repository\\ReactionRepository','XF\\Mvc\\Entity\\Entity','XF\\Entity\\ReactionContent','XF\\Entity\\ReactionTrait','XF\\Reaction\\AbstractHandler','Siropu\\Chat\\Entity\\Message','Siropu\\Chat\\Reaction\\RoomMessage','Siropu\\Chat\\Service\\Room\\ActionLogger']],JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
}
