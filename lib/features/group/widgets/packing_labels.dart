import '../../../common/models/packing.dart';
import '../../../l10n/l10n.dart';

/// Name of a suggested packing item (keys from `packing_template.dart`).
String packingItemLabel(AppLocalizations l10n, String key) => switch (key) {
      'idCard' => l10n.packingItemIdCard,
      'healthCard' => l10n.packingItemHealthCard,
      'tickets' => l10n.packingItemTickets,
      'wallet' => l10n.packingItemWallet,
      'phoneCharger' => l10n.packingItemPhoneCharger,
      'powerBank' => l10n.packingItemPowerBank,
      'headphones' => l10n.packingItemHeadphones,
      'plugAdapter' => l10n.packingItemPlugAdapter,
      'underwear' => l10n.packingItemUnderwear,
      'socks' => l10n.packingItemSocks,
      'tshirts' => l10n.packingItemTshirts,
      'trousers' => l10n.packingItemTrousers,
      'pajamas' => l10n.packingItemPajamas,
      'shoes' => l10n.packingItemShoes,
      'toothbrush' => l10n.packingItemToothbrush,
      'toothpaste' => l10n.packingItemToothpaste,
      'deodorant' => l10n.packingItemDeodorant,
      'medication' => l10n.packingItemMedication,
      'sunscreen' => l10n.packingItemSunscreen,
      'sunglasses' => l10n.packingItemSunglasses,
      'swimwear' => l10n.packingItemSwimwear,
      'warmJacket' => l10n.packingItemWarmJacket,
      'gloves' => l10n.packingItemGloves,
      'beanie' => l10n.packingItemBeanie,
      'rainJacket' => l10n.packingItemRainJacket,
      'keys' => l10n.packingItemKeys,
      'waterBottle' => l10n.packingItemWaterBottle,
      'speaker' => l10n.packingItemSpeaker,
      'firstAid' => l10n.packingItemFirstAid,
      'powerStrip' => l10n.packingItemPowerStrip,
      'cardGame' => l10n.packingItemCardGame,
      'hairDryer' => l10n.packingItemHairDryer,
      'shampoo' => l10n.packingItemShampoo,
      // A key from a newer app version.
      _ => key,
    };

/// An own item as shown, with its count ("Socks ×5").
String packingItemTitle(AppLocalizations l10n, PackingItem item) {
  final name =
      item.key != null ? packingItemLabel(l10n, item.key!) : (item.name ?? '');
  return item.qty != null && item.qty! > 1
      ? l10n.packingQty(name, item.qty!)
      : name;
}

String packingCategoryLabel(AppLocalizations l10n, PackingCategory c) =>
    switch (c) {
      PackingCategory.documents => l10n.packingCategoryDocuments,
      PackingCategory.tech => l10n.packingCategoryTech,
      PackingCategory.clothes => l10n.packingCategoryClothes,
      PackingCategory.toiletries => l10n.packingCategoryToiletries,
      PackingCategory.weather => l10n.packingCategoryWeather,
      PackingCategory.other => l10n.packingCategoryOther,
      PackingCategory.own => l10n.packingCategoryOwn,
    };
