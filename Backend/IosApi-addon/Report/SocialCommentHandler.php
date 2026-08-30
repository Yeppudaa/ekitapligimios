<?php

namespace Ekitapligim\IosApi\Report;

use XF\Entity\Report;
use XF\Mvc\Entity\Entity;

class SocialCommentHandler extends \XF\Report\AbstractHandler
{
	protected function canViewContent(Report $report) { return true; }
	protected function canActionContent(Report $report)
	{
		$visitor = \XF::visitor();
		return $visitor->is_admin || $visitor->is_moderator || $visitor->hasPermission('ekSocial', 'moderate');
	}
	public function setupReportEntityContent(Report $report, Entity $comment)
	{
		$report->content_user_id = (int) $comment->user_id;
		$report->content_info = [
			'message' => (string) $comment->message,
			'comment_id' => (int) $comment->comment_id,
			'post_id' => (int) $comment->post_id,
			'user_id' => (int) $comment->user_id,
			'username' => (string) $comment->username,
		];
	}
	public function getContentTitle(Report $report) { return 'Kitap Gündemi yorumu #' . (int) $report->content_info['comment_id']; }
	public function getContentMessage(Report $report) { return (string) $report->content_info['message']; }
	public function getContentLink(Report $report) { return \XF::app()->router('public')->buildLink('canonical:kitap-gundemi', ['post_id' => (int) $report->content_info['post_id']]); }
	public function getEntityWith() { return ['Post', 'User']; }
}
