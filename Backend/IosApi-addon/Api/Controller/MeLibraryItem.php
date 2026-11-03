<?php
namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\LibraryShelfManager;
use XF\Mvc\ParameterBag;

class MeLibraryItem extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
    public function actionPut(ParameterBag $params)
    {
        $this->assertMobileWriteScope();
        $visitor = $this->assertRegisteredApiUser();
        $book = $this->assertBook((int) $params->thread_id);
        try
        {
            $input = $this->libraryInput();
            $state = $this->optionalField($input, 'shelf_state', 'shelfState');
            if ($state !== null && !is_string($state)) { throw new \InvalidArgumentException('Invalid shelf state.'); }
            $favorite = $this->optionalField($input, 'is_favorite', 'isFavorite');
            if ($favorite !== null)
            {
                if (in_array($favorite, [true, 1, '1', 'true'], true)) { $favorite = true; }
                elseif (in_array($favorite, [false, 0, '0', 'false'], true)) { $favorite = false; }
                else { throw new \InvalidArgumentException('Invalid favorite state.'); }
            }
            $item = (new LibraryShelfManager())->update($book, $visitor, $state, $favorite);
        }
        catch (\InvalidArgumentException $e) { return $this->apiError('Invalid library update.', 'library_update_invalid', null, 400); }
        catch (\DomainException $e) { return $this->apiError('Library update not permitted.', 'library_update_forbidden', null, 403); }
        catch (\Throwable $e) { return $this->apiError('Shelf could not be updated.', 'shelf_error', null, 503); }
        // Shelf/favorite updates must never turn an EPUB CFI into a PDF page or overwrite a newer web position.
        return $this->apiResult(['success' => true, 'item' => $item]);
    }

    private function libraryInput(): array
    {
        $input = $this->request->getInput();
        // XenForo versions parsing only the bare PUT MIME leave iOS UTF-8 forms empty.
        $contentType = strtolower(trim(explode(';', (string) $this->request->getServer('CONTENT_TYPE', ''))[0]));
        if ($contentType === 'application/x-www-form-urlencoded')
        {
            $body = (string) $this->request->getInputRaw();
            if (strlen($body) > 8192) { throw new \InvalidArgumentException('Library request too large.'); }
            if ($body !== '')
            {
                parse_str($body, $form);
                $input = array_replace($input, $form);
            }
        }
        return $input;
    }

    private function optionalField(array $input, string $snake, string $camel)
    {
        if (array_key_exists($snake, $input) && array_key_exists($camel, $input) && $input[$snake] !== $input[$camel])
        {
            throw new \InvalidArgumentException('Conflicting library update fields.');
        }
        if (array_key_exists($snake, $input))
        {
            if ($input[$snake] === null) { throw new \InvalidArgumentException('Invalid library update field.'); }
            return $input[$snake];
        }
        if (array_key_exists($camel, $input))
        {
            if ($input[$camel] === null) { throw new \InvalidArgumentException('Invalid library update field.'); }
            return $input[$camel];
        }
        return null;
    }
}
