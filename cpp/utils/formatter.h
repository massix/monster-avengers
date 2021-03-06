#ifndef _MONSTER_AVENGERS_ARMOR_SET_
#define _MONSTER_AVENGERS_ARMOR_SET_

#include <cstdio>
#include <cwchar>
#include <string>
#include <fstream>
#include <iostream>
#include <memory>
#include <unordered_map>
#include <functional>

#include "lisp/lisp_object.h"
#include "utils/output_specs.h"

namespace monster_avengers {

  template <OutputSpec Spec>
  class ArmorSetFormatter {
  public:
    virtual void operator()(const ArmorSet &armor_set) = 0;
  };

  template <>
  class ArmorSetFormatter<SCREEN> {
  public:
    ArmorSetFormatter(const std::string &unused_path,
                      const DataSet *data,
                      const Query &query)
      : solver_(*data, query.effects, query.jewel_filter), 
        data_(data) {}

    void operator()(const ArmorSet &armor_set) {
      ArmorResult result(*data_, solver_, armor_set);
      wprintf(L"---------- ArmorSet (defense %d) ----------\n", 
              result.defense);
      WriteGear(result.gear);
      WriteArmor(HEAD, result.head);
      WriteArmor(BODY, result.body);
      WriteArmor(HANDS, result.hands);
      WriteArmor(WAIST, result.waist);
      WriteArmor(FEET, result.feet);
      WriteAmulet(result.amulet);
      
      for (const JewelPlan &plan : result.plans) {
        wprintf(L"Jewel Plan:");
        for (const JewelPair &pair : plan.body_plan) {
          wprintf(L" | %ls[BODY] x %d", 
                  pair.name.c_str(),
                  pair.quantity);
        }
        for (const JewelPair &pair : plan.plan) {
          wprintf(L" | %ls x %d", 
                  pair.name.c_str(),
                  pair.quantity);
        }
        wprintf(L" |\n");
        for (const SummaryItem &item : plan.summary) {
          wprintf(L"%ls(%d)  ", item.name.c_str(), item.points);
        }
        wprintf(L"\n");
      }
      wprintf(L"\n");
    }
    
  private:
    void WriteGear(const PackedArmor &gear) const {
      wprintf(L"[ GEAR ] [%s] [Rare ??] %ls\n", 
              HoleText(gear.holes).c_str(),
              gear.name.c_str());
    }

    void WriteArmor(ArmorPart part, const PackedArmor &armor) const {
      wprintf(L"[%s] [%s] [Rare %02d] %ls", 
              PartText(part).c_str(),
              HoleText(armor.holes).c_str(),
              armor.rare,
              armor.name.c_str());
      if (L"true" == armor.torso_up) {
        wprintf(L"(%ls)",
                data_->skill_system(data_->torso_up_id).name.c_str());
      }
      wprintf(L"        | Material:");
      for (const LanguageText &material : armor.material) {
        wprintf(L" %ls", material.c_str());
      }
      wprintf(L"\n");
    }

    void WriteAmulet(const PackedArmor &amulet) const {
      wprintf(L"[AMULET] [%s] [Rare ??] %ls\n", 
              HoleText(amulet.holes).c_str(),
              amulet.name.c_str());
    }
    
    std::string HoleText(int holes) const {
      switch (holes) {
      case 1: return "O--";
      case 2: return "OO-";
      case 3: return "OOO";
      default: return "---";
      }
    }

    std::string PartText(ArmorPart part) const {
      switch (part) {
      case HEAD: return " HEAD ";
      case BODY: return " BODY ";
      case HANDS: return " ARMS ";
      case WAIST: return " LEGS ";
      case FEET: return " FEET ";
      default: return "---";
      }
    }

    const JewelSolver solver_;
    const DataSet *data_;
  };


  template <>
  class ArmorSetFormatter<LISP> {
  public:
    ArmorSetFormatter(const std::string file_name, 
                      const DataSet *data,
                      const Query &query)
      : solver_(*data, query.effects, query.jewel_filter), 
        data_(data) {
      output_stream_.reset(new std::wofstream(file_name));
      if (!output_stream_->good()) {
        Log(FATAL, L"error while opening %s.", file_name.c_str());
        exit(-1);
      }
      output_stream_->imbue(LOCALE_UTF8);
    }

    void operator()(const ArmorSet &armor_set) {
      ToFile(armor_set);
    }

  private:
    // Output to specified file.
    void ToFile(const ArmorSet &armor_set) {
      (*output_stream_) << ArmorResult(*data_, solver_, armor_set) << "\n";
    }

    std::unique_ptr<std::wofstream> output_stream_;
    const JewelSolver solver_;
    const DataSet *data_;
  };

  template <>
  class ArmorSetFormatter<JSON> {
  public:
    ArmorSetFormatter(const std::string file_name, 
                      const DataSet *data,
                      const Query &query)
      : solver_(*data, query.effects, query.jewel_filter), 
        data_(data) {
      output_stream_.reset(new std::wofstream(file_name));
      if (!output_stream_->good()) {
        Log(FATAL, L"error while opening %s.", file_name.c_str());
        exit(-1);
      }
      output_stream_->imbue(LOCALE_UTF8);
    }

    void operator()(const ArmorSet &armor_set) {
      ToFile(armor_set);
    }

  private:
    // Output to specified file.
    void ToFile(const ArmorSet &armor_set) {
      lisp::Object result = 
        JsonArmorResult(*data_, solver_, armor_set).Format();
      result.OutputJson(output_stream_.get());
    }

    std::unique_ptr<std::wofstream> output_stream_;
    const JewelSolver solver_;
    const DataSet *data_;
  };

  class ResultSerializer {
  public:
    ResultSerializer(const DataSet *data,
                     const Query &query)
      : solver_(*data, query.effects, query.jewel_filter), 
        data_(data) {
      result_ = lisp::Object::List();
    }
    
    void Add(const ArmorSet &armor_set) {
      result_.Push(JsonArmorResult(*data_,
                                   solver_,
                                   armor_set).Format());
    }

    std::wstring ToString() {
      std::wostringstream output_;
      output_.imbue(LOCALE_UTF8);
      result_.OutputJson(&output_);
      return output_.str();
    }

  private:

    const JewelSolver solver_;
    const DataSet *data_;
    lisp::Object result_;
  };

  class ExploreFormatter {
  public:
    ExploreFormatter(const std::string &file_name) 
      : to_screen_("" == file_name) {
      if (!to_screen_) {
        output_stream_.reset(new std::wofstream(file_name));
        if (!output_stream_->good()) {
          Log(FATAL, L"error while opening %s.", file_name.c_str());
          exit(-1);
        }
        output_stream_->imbue(LOCALE_UTF8);
      }
    }

    void Push(int skill_id, bool pass, const LanguageText &name, 
              double duration) {
      if (to_screen_) {
        wprintf(L"%.4lf sec, (%03d) %ls %s\n",
                duration,
                skill_id,
                name.c_str(),
                pass ? "[PASS]" : "[fail]");
      } else {
        (*output_stream_) << "(" << skill_id << " "
                          << (pass ? ":PASS" : ":FAIL") << ")\n";
        output_stream_->flush();
      }
    }
    
  private:
    bool to_screen_;
    std::unique_ptr<std::wofstream> output_stream_;
  };


  class EncodeFormatter {
  public:
    EncodeFormatter(const DataSet *data,
		    const Query &query)
      : data_(data), solver_(*data, query.effects, query.jewel_filter) {}
    
    void operator()(const ArmorSet &armor_set, std::string *output) {
      EncodedArmorSet encoded(*data_, solver_, armor_set);
      *output += "(";
	
      AppendGear(encoded[GEAR], output);
      AppendPiece(":HEAD", encoded[HEAD], output);
      AppendPiece(":BODY", encoded[BODY], output);
      AppendPiece(":ARMS", encoded[HANDS], output);
      AppendPiece(":WAIST", encoded[WAIST], output);
      AppendPiece(":LEGS", encoded[FEET], output);
      AppendAmulet(encoded[AMULET], output);
      
      *output += ")\n";
    }

  private:

    void AppendGear(const EncodedArmorPiece &gear, std::string *output) {
      *output += ":GEAR (";
      *output += std::to_string(data_->armor(gear.id).holes);
      *output += " ";
      AppendNumberVector(gear.jewel_ids, output);
      *output += ") ";
    }
    
    void AppendPiece(const std::string &name,
		     const EncodedArmorPiece &piece,
		     std::string *output) {
      *output += name + " (";
      *output += std::to_string(piece.id);
      *output += " ";
      AppendNumberVector(piece.jewel_ids, output);
      *output += ") ";
    }

    void AppendAmulet(const EncodedArmorPiece &amulet, std::string *output) {
      *output += ":AMULET (";
      std::vector<int> effects;
      for (const Effect &effect : data_->armor(amulet.id).effects) {
	effects.push_back(effect.skill_id + 1);
	effects.push_back(effect.points);
      }
      AppendNumberVector(effects, output);
      *output += " ";
      AppendNumberVector(amulet.jewel_ids, output);
      *output += ") ";
    }

    void AppendNumberVector(const std::vector<int> &input, 
			    std::string *output) {
      *output += " (";
      if (!input.empty()) *output += std::to_string(input[0]);
      for (int i = 1; i < input.size(); ++i) {
	*output += " " + std::to_string(input[i]);
      }
      *output += ")";
    }
    
    const DataSet *data_;
    const JewelSolver solver_;
  };
}  // namespace monster_avengers


#endif  // _MONSTER_AVENGERS_ARMOR_SET_

