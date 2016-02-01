#include "spellchecker_mac.h"
#include "spellchecker_hunspell.h"

#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>

namespace spellchecker {


MacSpellchecker::MacSpellchecker() {
  this->spellChecker = [NSSpellChecker sharedSpellChecker];
  [this->spellChecker setAutomaticallyIdentifiesLanguages: NO];
}

MacSpellchecker::~MacSpellchecker() {
}

bool MacSpellchecker::SetDictionary(const std::string& language, const std::string& path) {
  @autoreleasepool {
    NSString* lang = [NSString stringWithUTF8String: language.c_str()];
    return [this->spellChecker setLanguage: lang] == YES;
  }
}

std::vector<std::string> MacSpellchecker::GetAvailableDictionaries(const std::string& path) {
  std::vector<std::string> ret;

  @autoreleasepool {
    NSArray* languages = [this->spellChecker availableLanguages];

    for (size_t i = 0; i < languages.count; ++i) {
      ret.push_back([[languages objectAtIndex:i] UTF8String]);
    }
  }

  return ret;
}

bool MacSpellchecker::IsMisspelled(const std::string& word) {
  bool result;

  @autoreleasepool {
    NSString* misspelling = [NSString stringWithUTF8String:word.c_str()];
    NSRange range = [this->spellChecker checkSpellingOfString:misspelling
                                                   startingAt:0];

    result = range.length > 0;
  }

  return result;
}

std::vector<MisspelledRange> MacSpellchecker::CheckSpelling(const uint16_t *text, size_t length) {
  std::vector<MisspelledRange> result;

  @autoreleasepool {
    NSData *data = [[NSData alloc] initWithBytesNoCopy:(void *)(text) length:(length * 2) freeWhenDone:NO];
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF16LittleEndianStringEncoding];
    NSArray *misspellings = [this->spellChecker checkString:string
                                                      range:NSMakeRange(0, string.length)
                                                      types:NSTextCheckingTypeSpelling
                                                    options:nil
                                     inSpellDocumentWithTag:0
                                                orthography:nil
                                                  wordCount:nil];
    for (NSTextCheckingResult *misspelling in misspellings) {
      MisspelledRange range;
      range.start = misspelling.range.location;
      range.end = misspelling.range.location + misspelling.range.length;
      result.push_back(range);
    }
  }

  return result;
}

void MacSpellchecker::Add(const std::string& word) {
  @autoreleasepool {
    NSString* newWord = [NSString stringWithUTF8String:word.c_str()];
    [this->spellChecker learnWord:newWord];
  }
}

std::vector<std::string> MacSpellchecker::GetCorrectionsForMisspelling(const std::string& word) {
  std::vector<std::string> corrections;

  @autoreleasepool {
    NSString* misspelling = [NSString stringWithUTF8String:word.c_str()];
    NSString* language = [this->spellChecker language];
    NSRange range;

    range.location = 0;
    range.length = [misspelling length];

    NSArray* guesses = [this->spellChecker guessesForWordRange:range
                                                      inString:misspelling
                                                      language:language
                                        inSpellDocumentWithTag:0];

    corrections.reserve(guesses.count);

    for (size_t i = 0; i < guesses.count; ++i) {
      corrections.push_back([[guesses objectAtIndex:i] UTF8String]);
    }
  }

  return corrections;
}

SpellcheckerImplementation* SpellcheckerFactory::CreateSpellchecker() {
#ifdef USE_HUNSPELL
  if (getenv("SPELLCHECKER_PREFER_HUNSPELL")) {
    return new HunspellSpellchecker();
  }
#endif

  return new MacSpellchecker();
}

}  // namespace spellchecker
