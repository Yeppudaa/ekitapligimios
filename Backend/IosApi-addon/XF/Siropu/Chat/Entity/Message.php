<?php

namespace Ekitapligim\IosApi\XF\Siropu\Chat\Entity;

use Ekitapligim\IosApi\Service\ChatInteraction;
use Ekitapligim\IosApi\Service\ChatPushProducer;

class Message extends XFCP_Message
{
	public function getQuoteWrapper($inner)
	{
		$quote = parent::getQuoteWrapper($inner);
		return ChatPushProducer::isPublicMessage($this) ? ChatInteraction::withMessageReference($quote, $this) : $quote;
	}
}
