<?php

namespace Ekitapligim\MobileApi\Pub\Controller;

use Ekitapligim\MobileApi\Service\MobileSession;
use XF\Api\Mvc\Reply\ApiResult;
use XF\Entity\ResultInterface;
use XF\Mvc\Entity\AbstractCollection;
use XF\Mvc\Entity\Entity;
use XF\Mvc\ParameterBag;
use XF\Mvc\Reply\AbstractReply;
use XF\Mvc\RouteMatch;

trait PublicEndpointTrait
{
	public function setupFromMatch(RouteMatch $match)
	{
		parent::setupFromMatch($match);
		$this->setResponseType('json');
		$this->applyMobileBearerVisitor();
	}

	public function checkCsrfIfNeeded($action, ParameterBag $params)
	{
		return;
	}

	public function applyReplyChanges($action, ParameterBag $params, AbstractReply &$reply)
	{
		if ($reply instanceof ApiResult)
		{
			$reply = $this->view('', '', [
				'innerContent' => $this->renderMobileApiValue($reply->getApiResult())
			]);
			$reply->setViewOption('skipDefaultJsonParams', true);
		}

		$reply->setResponseType('json');
	}

	public function actionIndex(ParameterBag $params)
	{
		return $this->dispatchMobileApiAction('', $params);
	}

	protected function dispatchMobileApiAction(string $suffix, ParameterBag $params)
	{
		$method = strtolower($this->request->getRequestMethod());
		$candidates = [];

		if ($method === 'post')
		{
			$candidates[] = 'actionPost' . $suffix;
		}
		else if ($method === 'delete')
		{
			$candidates[] = 'actionDelete' . $suffix;
		}
		else if ($method === 'patch')
		{
			$candidates[] = 'actionPatch' . $suffix;
		}
		else if ($method === 'put')
		{
			$candidates[] = 'actionPut' . $suffix;
		}

		if ($method === 'get' || $method === 'head')
		{
			$candidates[] = 'actionGet' . $suffix;
		}
		$candidates[] = 'action' . $suffix;

		foreach ($candidates AS $candidate)
		{
			if (is_callable([$this, $candidate]))
			{
				$reflection = new \ReflectionMethod($this, $candidate);
				return $reflection->getNumberOfParameters() > 0
					? $this->{$candidate}($params)
					: $this->{$candidate}();
			}
		}

		return $this->notFound();
	}

	protected function applyMobileBearerVisitor(): void
	{
		$userId = MobileSession::userIdForAccessToken(MobileSession::bearerToken($this->getMobileAuthorizationHeader()));
		if ($userId <= 0)
		{
			return;
		}

		$user = $this->em()->find('XF:User', $userId);
		if ($user)
		{
			\XF::setVisitor($user);
		}
	}

	protected function getMobileAuthorizationHeader(): string
	{
		$header = trim($this->request->getAuthorizationHeader());
		if ($header !== '')
		{
			return $header;
		}

		$header = trim((string) $this->request->getServer('REDIRECT_HTTP_AUTHORIZATION', ''));
		if ($header !== '')
		{
			return $header;
		}

		foreach (['apache_request_headers', 'getallheaders'] AS $function)
		{
			if (!function_exists($function))
			{
				continue;
			}

			$headers = $function();
			if (!is_array($headers))
			{
				continue;
			}

			foreach ($headers AS $name => $value)
			{
				if (strcasecmp((string) $name, 'Authorization') === 0)
				{
					return trim((string) $value);
				}
			}
		}

		return '';
	}

	protected function renderMobileApiValue($value)
	{
		if ($value instanceof ResultInterface)
		{
			$value = $value->render();
		}
		else if ($value instanceof Entity)
		{
			$value = $value->toApiResult()->render();
		}
		else if ($value instanceof AbstractCollection)
		{
			$value = $value->toApiResults();
		}

		if (is_array($value))
		{
			foreach ($value AS $key => $innerValue)
			{
				$value[$key] = $this->renderMobileApiValue($innerValue);
			}
		}
		else if (is_object($value) && method_exists($value, 'jsonSerialize'))
		{
			$value = $value->jsonSerialize();
		}
		else if (is_object($value) && method_exists($value, '__toString'))
		{
			$value = (string) $value;
		}

		return $value;
	}
}
