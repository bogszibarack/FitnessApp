using FitnessBackend.Models;

namespace FitnessBackend.Services
{
    /// <summary>
    /// Magyar ételmag ~250 gyakori étel + keresési aliasok (100 g makrók).
    /// Offline első találat — a külső API csak kiegészít.
    /// </summary>
    public static class HungarianFoodCatalog
    {
        public sealed class Entry
        {
            public required string Id { get; init; }
            public required string Name { get; init; }
            public double Calories { get; init; }
            public double Protein { get; init; }
            public double Carbs { get; init; }
            public double Fat { get; init; }
            public string[] Aliases { get; init; } = [];
            public FoodItem ToFoodItem() => new()
            {
                Id = Id,
                Name = Name,
                Calories = Calories,
                Protein = Protein,
                Carbs = Carbs,
                Fat = Fat,
            };
        }

        private static Entry E(string id, string name, double kcal, double p, double c, double f, params string[] aliases) =>
            new() { Id = id, Name = name, Calories = kcal, Protein = p, Carbs = c, Fat = f, Aliases = aliases };

        public static readonly IReadOnlyList<Entry> All =
        [
            E("hu_alma", "Alma", 52, 0.3, 14, 0.2, "apple", "piros alma", "zöld alma"),
            E("hu_korte", "Körte", 57, 0.4, 15, 0.1, "pear"),
            E("hu_banan", "Banán", 89, 1.1, 23, 0.3, "banana"),
            E("hu_narancs", "Narancs", 47, 0.9, 12, 0.1, "orange"),
            E("hu_szilva", "Szilva", 46, 0.7, 11, 0.3, "plum"),
            E("hu_eper", "Eper", 32, 0.7, 8, 0.3, "strawberry", "földieper"),
            E("hu_afonya", "Áfonya", 57, 0.7, 14, 0.3, "blueberry"),
            E("hu_málna", "Málna", 52, 1.2, 12, 0.7, "raspberry"),
            E("hu_szeder", "Szeder", 43, 1.4, 10, 0.5, "blackberry"),
            E("hu_meggy", "Meggy", 50, 1.0, 12, 0.3, "sour cherry"),
            E("hu_cseresznye", "Cseresznye", 63, 1.1, 16, 0.2, "cherry"),
            E("hu_szolo", "Szőlő", 67, 0.6, 17, 0.4, "grape", "szőlőszem"),
            E("hu_dinnye", "Görögdinnye", 30, 0.6, 8, 0.2, "watermelon", "görög dinnye", "dinnye"),
            E("hu_sargadinnye", "Sárgadinnye", 34, 0.8, 8, 0.2, "cantaloupe", "sárga dinnye"),
            E("hu_kivi", "Kivi", 61, 1.1, 15, 0.5, "kiwi"),
            E("hu_mango", "Mangó", 60, 0.8, 15, 0.4, "mango"),
            E("hu_ananas", "Ananász", 50, 0.5, 13, 0.1, "pineapple"),
            E("hu_citrom", "Citrom", 29, 1.1, 9, 0.3, "lemon"),
            E("hu_grapefruit", "Grapefruit", 42, 0.8, 11, 0.1),
            E("hu_barack", "Őszibarack", 39, 0.9, 10, 0.3, "peach", "barack"),
            E("hu_kajszi", "Kajszibarack", 48, 1.4, 11, 0.4, "apricot", "kajszi"),
            E("hu_nektarin", "Nektarin", 44, 1.1, 11, 0.3),
            E("hu_fige", "Füge", 74, 0.8, 19, 0.3, "fig"),
            E("hu_datolya", "Datolya", 282, 2.5, 75, 0.4, "date"),
            E("hu_mazsola", "Mazsola", 299, 3.1, 79, 0.5, "raisin"),
            E("hu_kokusz", "Kókuszreszelék", 660, 6.9, 24, 65, "coconut", "kókusz"),
            E("hu_paradicsom", "Paradicsom", 18, 0.9, 3.9, 0.2, "tomato"),
            E("hu_uborka", "Uborka", 16, 0.7, 3.6, 0.1, "cucumber"),
            E("hu_paprika", "Paprika (piros)", 31, 1.0, 6.0, 0.3, "pepper", "kaliforniai paprika"),
            E("hu_tvpaprika", "TV paprika", 27, 1.0, 5.0, 0.2, "zöld paprika"),
            E("hu_sarrep", "Sárgarépa", 41, 0.9, 10, 0.2, "carrot", "répa"),
            E("hu_hagyma", "Vöröshagyma", 40, 1.1, 9.3, 0.1, "onion", "hagyma"),
            E("hu_lilahagyma", "Lilahagyma", 40, 1.1, 9.3, 0.1, "red onion"),
            E("hu_fokhag", "Fokhagyma", 149, 6.4, 33, 0.5, "garlic"),
            E("hu_brokkoli", "Brokkoli", 34, 2.8, 7.0, 0.4, "broccoli"),
            E("hu_karfiol", "Karfiol", 25, 1.9, 5.0, 0.3, "cauliflower"),
            E("hu_spenot", "Spenót", 23, 2.9, 3.6, 0.4, "spinach"),
            E("hu_kelbimbo", "Kelbimbó", 43, 3.4, 9.0, 0.3, "brussels sprouts"),
            E("hu_kelkaposzta", "Kelkáposzta", 49, 3.3, 9, 0.7, "kale"),
            E("hu_fejeskaposzta", "Fejeskáposzta", 25, 1.3, 6, 0.1, "cabbage", "káposzta"),
            E("hu_cukkini", "Cukkini", 17, 1.2, 3.1, 0.3, "zucchini"),
            E("hu_padlizsan", "Padlizsán", 25, 1.0, 6, 0.2, "eggplant", "aubergine"),
            E("hu_sutotok", "Sütőtök", 26, 1.0, 6.5, 0.1, "pumpkin", "tök"),
            E("hu_gomba", "Csiperkegomba", 22, 3.1, 3.3, 0.3, "mushroom", "gomba"),
            E("hu_salata", "Saláta (fejes)", 15, 1.4, 2.9, 0.2, "lettuce", "fejes saláta"),
            E("hu_rukkola", "Rukkola", 25, 2.6, 3.7, 0.7, "arugula", "rucola"),
            E("hu_retek", "Retek", 16, 0.7, 3.4, 0.1, "radish"),
            E("hu_cékla", "Cékla", 43, 1.6, 10, 0.2, "beetroot"),
            E("hu_zeller", "Zeller", 16, 0.7, 3, 0.2, "celery"),
            E("hu_spárga", "Spárga", 20, 2.2, 3.9, 0.1, "asparagus"),
            E("hu_kukorica", "Csemegekukorica", 86, 3.3, 19, 1.2, "corn", "kukorica"),
            E("hu_zoldborso", "Zöldborsó", 81, 5.4, 14, 0.4, "peas", "borsó", "zöld borsó"),
            E("hu_zoldbab", "Zöldbab", 31, 1.8, 7, 0.2, "green beans"),
            E("hu_edesburgo", "Édesburgonya", 86, 1.6, 20, 0.1, "sweet potato", "batáta"),
            E("hu_krumpli", "Burgonya (főtt)", 87, 1.9, 20, 0.1, "potato", "krumpli", "főtt krumpli", "főtt burgonya"),
            E("hu_sultkrum", "Sült krumpli", 280, 3.5, 36, 14, "french fries", "hasábburgonya", "hasáb", "sültburgonya", "pommes"),
            E("hu_pure", "Burgonyapüré", 90, 2.0, 15, 2.5, "mashed potato", "krumplipüré", "püré"),
            E("hu_csirkemell", "Csirkemell", 165, 31, 0, 3.6, "chicken breast", "csirke mell", "grill csirkemell"),
            E("hu_csirkecomb", "Csirkecomb", 215, 26, 0, 12, "chicken thigh", "csirke comb"),
            E("hu_csirkeszarny", "Csirkeszárny", 203, 18, 0, 14, "chicken wing", "szárny"),
            E("hu_egeszcsirke", "Sült csirke", 239, 27, 0, 14, "roast chicken", "egész csirke"),
            E("hu_pulykamell", "Pulykamell", 189, 29, 0, 7.5, "turkey breast", "pulyka"),
            E("hu_marha", "Marhahús", 250, 26, 0, 17, "beef", "marha", "marhahus"),
            E("hu_marha_sovany", "Marhahús (sovány)", 180, 28, 0, 7, "lean beef"),
            E("hu_sertes", "Sertéshús", 242, 27, 0, 14, "pork", "sertés", "disznóhús"),
            E("hu_serteskaraj", "Sertéskaraj", 200, 28, 0, 9, "pork loin", "karaj"),
            E("hu_sertescomb", "Sertéscomb", 180, 27, 0, 7, "pork ham meat"),
            E("hu_daralthus", "Darált hús (sertés)", 260, 17, 0, 21, "minced meat", "darált sertés", "mince"),
            E("hu_daraltmarha", "Darált marha", 250, 17, 0, 20, "ground beef", "darált marhahús"),
            E("hu_daraltcsirke", "Darált csirke", 150, 20, 0, 8, "ground chicken"),
            E("hu_sonka", "Sonka", 145, 21, 1.5, 6, "ham", "párizsi sonka"),
            E("hu_parizsi", "Párizsi", 203, 11, 2, 16, "bologna", "parizer"),
            E("hu_szalami", "Szalámi", 406, 22, 2, 35, "salami"),
            E("hu_kolbasz", "Kolbász", 300, 15, 2, 26, "sausage", "sütnivaló kolbász"),
            E("hu_virsli", "Virsli", 280, 12, 2, 25, "frankfurter", "hot dog virsli"),
            E("hu_bacon", "Bacon", 400, 13, 1, 38, "szalonna", "füstölt szalonna"),
            E("hu_lazac", "Lazac", 208, 20, 0, 13, "salmon"),
            E("hu_tonhal", "Tonhal (konzerv)", 116, 26, 0, 1, "tuna", "tonhal konzerv"),
            E("hu_ponty", "Ponty", 162, 18, 0, 9, "carp"),
            E("hu_harcsa", "Harcsa", 105, 18, 0, 3.5, "catfish"),
            E("hu_fogas", "Fogas", 90, 19, 0, 1, "pike-perch", "süllő"),
            E("hu_garnela", "Garnéla", 99, 24, 0, 0.3, "shrimp", "prawn", "rák"),
            E("hu_tojas", "Tojás (egész)", 155, 13, 1.1, 11, "egg", "tojás", "főtt tojás"),
            E("hu_tojasfeher", "Tojásfehérje", 52, 11, 0.7, 0.2, "egg white"),
            E("hu_tojassarg", "Tojássárgája", 322, 16, 3.6, 27, "egg yolk"),
            E("hu_rantotta", "Rántotta", 180, 12, 1.5, 14, "scrambled eggs", "tojásrántotta"),
            E("hu_omlett", "Omlett", 160, 12, 1.5, 12, "omelette", "omelett"),
            E("hu_tej", "Tej (2,8%)", 50, 3.4, 4.8, 2.0, "milk", "tej", "zsíros tej"),
            E("hu_tej15", "Tej (1,5%)", 47, 3.4, 4.9, 1.5, "light milk", "félzsíros tej"),
            E("hu_folytej", "Fölözött tej", 35, 3.4, 5.0, 0.1, "skim milk", "sovány tej"),
            E("hu_joghurt", "Joghurt (natúr)", 61, 3.5, 4.7, 3.3, "yogurt", "natúr joghurt"),
            E("hu_gorog", "Görög joghurt", 97, 9.0, 3.6, 5.0, "greek yogurt", "görögjoghurt"),
            E("hu_gorog_sovany", "Görög joghurt (0%)", 57, 10, 3.5, 0.2, "fat free greek yogurt"),
            E("hu_kefir", "Kefir", 55, 3.3, 4.5, 2.5),
            E("hu_turo", "Túró (sovány)", 98, 11, 3.4, 4.3, "cottage cheese", "túró"),
            E("hu_turokrem", "Túrókrém", 180, 8, 12, 11),
            E("hu_trappista", "Trappista sajt", 356, 26, 1.3, 28, "trappista", "sajt"),
            E("hu_mozzarella", "Mozzarella", 280, 28, 2.2, 17),
            E("hu_feta", "Feta sajt", 264, 14, 4, 21, "feta"),
            E("hu_cheddar", "Cheddar sajt", 403, 25, 1.3, 33, "cheddar"),
            E("hu_parmezan", "Parmezán", 431, 38, 4, 29, "parmesan", "parmezán sajt"),
            E("hu_camembert", "Camembert", 300, 20, 0.5, 24),
            E("hu_tejfol", "Tejföl (20%)", 200, 2.5, 3.5, 20, "sour cream", "tejföl"),
            E("hu_tejfol12", "Tejföl (12%)", 130, 2.8, 4, 12, "light sour cream"),
            E("hu_tejszin", "Tejszín (30%)", 300, 2.3, 3.0, 30, "cream", "habtejszín"),
            E("hu_vaj", "Vaj", 717, 0.9, 0.1, 81, "butter"),
            E("hu_margarin", "Margarin", 720, 0.2, 0.5, 80, "margarine"),
            E("hu_rizs_fo", "Rizs (főtt)", 130, 2.7, 28, 0.3, "rice", "főtt rizs", "fehér rizs"),
            E("hu_rizs_ny", "Rizs (nyers)", 361, 7.0, 80, 0.7, "raw rice"),
            E("hu_barnarizs", "Barna rizs (főtt)", 112, 2.3, 24, 0.8, "brown rice"),
            E("hu_teszta", "Tészta (főtt)", 158, 5.8, 31, 0.9, "pasta", "főtt tészta", "spagetti", "penne", "fusilli"),
            E("hu_teszta_ny", "Tészta (nyers)", 370, 13, 75, 1.5, "dry pasta"),
            E("hu_nokedli", "Nokedli", 145, 4.5, 28, 2, "galuska", "spaetzle", "nokedli galuska"),
            E("hu_tarhonya", "Tarhonya (főtt)", 140, 4, 28, 1.5, "egg barley"),
            E("hu_kasa", "Kása (hajdina)", 100, 3.5, 20, 0.8, "buckwheat", "hajdina"),
            E("hu_kuskus", "Kuszusz (főtt)", 112, 3.8, 23, 0.2, "couscous", "kuszusz"),
            E("hu_quinoa", "Quinoa (főtt)", 120, 4.4, 22, 1.9, "quinoa"),
            E("hu_zab", "Zabpehely", 389, 17, 66, 7, "oats", "zab", "oatmeal dry"),
            E("hu_zabkasa", "Zabkása (főtt)", 71, 2.5, 12, 1.4, "oatmeal", "zabkása", "porridge"),
            E("hu_muesli", "Müzli", 420, 10, 65, 14, "granola", "muesli", "granola müzli"),
            E("hu_kukoricapehely", "Kukoricapehely", 356, 7.5, 78, 1.9, "corn flakes"),
            E("hu_kenyer", "Kenyér (fehér)", 265, 9, 49, 3.2, "bread", "fehér kenyér", "vekni"),
            E("hu_barnaken", "Kenyér (barna)", 247, 8.9, 45, 3.4, "brown bread", "barna kenyér", "teljes kiőrlésű kenyér"),
            E("hu_toast", "Toast kenyér", 270, 8, 52, 3, "toast"),
            E("hu_zsemle", "Zsemle", 280, 9, 55, 3, "bread roll"),
            E("hu_kifli", "Kifli", 300, 8, 55, 5),
            E("hu_pogacsa", "Pogácsa", 380, 8, 40, 20),
            E("hu_tortilla", "Tortilla (búza)", 300, 8, 50, 7, "wrap tortilla"),
            E("hu_lencse", "Lencse (főtt)", 116, 9, 20, 0.4, "lentil", "főtt lencse"),
            E("hu_bab", "Bab (főtt)", 127, 8.7, 23, 0.5, "beans", "főtt bab", "vesebab"),
            E("hu_csicseri", "Csicseriborsó (főtt)", 164, 8.9, 27, 2.6, "chickpea", "csicseriborsó"),
            E("hu_oliva", "Olívaolaj", 884, 0, 0, 100, "olive oil", "olíva"),
            E("hu_napraforgo", "Napraforgóolaj", 884, 0, 0, 100, "sunflower oil", "étolaj", "olaj"),
            E("hu_kókuszolaj", "Kókuszolaj", 892, 0, 0, 99, "coconut oil"),
            E("hu_mogyoro", "Mogyoró", 607, 14, 16, 56, "peanut"),
            E("hu_dio", "Dió", 654, 15, 14, 65, "walnut"),
            E("hu_mandula", "Mandula", 579, 21, 22, 50, "almond"),
            E("hu_kesu", "Kesüdió", 553, 18, 30, 44, "cashew", "kesudió"),
            E("hu_pisztacia", "Pisztácia", 560, 20, 28, 45, "pistachio"),
            E("hu_mogyorova", "Mogyoróvaj", 588, 25, 20, 50, "peanut butter"),
            E("hu_avokado", "Avokádó", 160, 2, 9, 15, "avocado"),
            E("hu_chia", "Chia mag", 486, 17, 42, 31, "chia"),
            E("hu_lenmag", "Lenmag", 534, 18, 29, 42, "flaxseed"),
            E("hu_napraforgmag", "Napraforgómag", 584, 21, 20, 51, "sunflower seeds"),
            E("hu_rantotthus", "Rántott hús", 280, 18, 14, 17, "schnitzel", "rántotthús", "panirozott hús", "rántott szelet"),
            E("hu_becsi", "Bécsi szelet", 297, 19, 15, 18, "wiener schnitzel", "bécsi", "becsi szelet"),
            E("hu_rantottcsirk", "Rántott csirkemell", 220, 24, 10, 9, "breaded chicken", "rántott csirke"),
            E("hu_rantottsajt", "Rántott sajt", 310, 14, 18, 20, "breaded cheese", "rántott trappista"),
            E("hu_fasirt", "Fasírt", 240, 16, 8, 16, "meatball", "fasírozott", "húsgombóc"),
            E("hu_porkolt_mar", "Marhapörkölt", 180, 18, 4, 10, "pörkölt", "marha pörkölt", "gulyáshús"),
            E("hu_porkolt_ser", "Sertéspörkölt", 195, 17, 4, 12, "sertés pörkölt", "disznópörkölt"),
            E("hu_csirkepapr", "Csirkepaprikás", 160, 16, 5, 8, "paprikás csirke", "csirke paprikás"),
            E("hu_paprikaskrumpli", "Paprikás krumpli", 110, 3, 16, 4),
            E("hu_gulyas", "Gulyásleves", 75, 6, 6, 3, "goulash", "gulyás", "bográcsgulyás"),
            E("hu_halaszle", "Halászlé", 70, 8, 3, 2.5, "fisherman soup"),
            E("hu_husleves", "Húsleves", 40, 4, 3, 1.2, "chicken soup", "tyúkhúsleves", "erőleves"),
            E("hu_frankfurti", "Frankfurti leves", 55, 3, 5, 2.5),
            E("hu_borsoleves", "Borsóleves", 55, 3, 8, 1.5),
            E("hu_babgulyas", "Babgulyás", 90, 6, 10, 3),
            E("hu_jokai", "Jókai bableves", 95, 6, 11, 3.5, "bableves"),
            E("hu_magyaros", "Magyaros gulyásleves", 80, 6, 7, 3),
            E("hu_toltottpap", "Töltött paprika", 120, 8, 10, 5, "stuffed pepper"),
            E("hu_toltottkaposzta", "Töltött káposzta", 130, 8, 9, 7, "töltöttkáposzta"),
            E("hu_rakottkru", "Rakott krumpli", 150, 8, 14, 7, "rakottkrumpli"),
            E("hu_rakottkel", "Rakott kelkáposzta", 140, 8, 10, 7),
            E("hu_lecso", "Lecsó", 55, 1.5, 7, 2.5),
            E("hu_brasso", "Brassói aprópecsenye", 220, 16, 12, 12, "brassói"),
            E("hu_vadas", "Vadas mártás hússal", 160, 12, 10, 7, "vadas"),
            E("hu_stefania", "Stefánia szelet", 210, 16, 8, 12),
            E("hu_sertesporkolt_nokedli", "Sertéspörkölt nokedlivel", 180, 12, 16, 7),
            E("hu_csirkeporkolt", "Csirkepörkölt", 155, 16, 4, 8),
            E("hu_marhawok", "Marhawok zöldséggel", 140, 12, 10, 5, "wok"),
            E("hu_krumplifo", "Krumplifőzelék", 80, 2, 14, 2, "burgonyafőzelék"),
            E("hu_tokfo", "Tökfőzelék", 70, 2, 10, 2.5),
            E("hu_spenotfo", "Spenótfőzelék", 75, 3.5, 8, 3.5),
            E("hu_borsofo", "Borsófőzelék", 85, 4, 12, 2.5, "zöldborsó főzelék"),
            E("hu_babfo", "Babfőzelék", 95, 5, 14, 2),
            E("hu_lencsefo", "Lencsefőzelék", 100, 6, 15, 2),
            E("hu_karfiolfo", "Karfiolfőzelék", 70, 3, 8, 3),
            E("hu_zoldborso_fozelek", "Zöldborsófőzelék", 85, 4, 12, 2.5),
            E("hu_onlyfozelek", "Sóska főzelék", 65, 2, 8, 3, "sóskafőzelék"),
            E("hu_rantotthal", "Rántott hal", 220, 16, 12, 12, "fish and chips", "rántott fogas"),
            E("hu_halpogacsa", "Halpogácsa", 250, 12, 20, 14),
            E("hu_sushi", "Sushi (lazacos)", 150, 6, 25, 3, "sushi"),
            E("hu_gyros", "Gyros pitában", 250, 14, 25, 10, "gyros", "girospita"),
            E("hu_kebab", "Kebab", 260, 15, 22, 12, "döner", "doner"),
            E("hu_hamburger", "Hamburger", 250, 13, 25, 11, "burger", "sajtbürger", "cheeseburger"),
            E("hu_hotdog", "Hot dog", 290, 11, 25, 16, "virslis zsemle"),
            E("hu_pizza", "Pizza", 266, 11, 33, 10, "pizza szelet"),
            E("hu_szendvics", "Szendvics (sonkás)", 230, 12, 25, 9, "sandwich", "szendvics"),
            E("hu_wrap", "Wrap (csirkés)", 220, 14, 24, 8, "csirke wrap"),
            E("hu_salata_csirk", "Csirkés saláta", 120, 14, 6, 5, "chicken salad"),
            E("hu_cezar", "Cézár saláta", 180, 10, 8, 12, "caesar salad", "cezar salata"),
            E("hu_gordog", "Görög saláta", 110, 4, 8, 7, "greek salad"),
            E("hu_palacsinta", "Palacsinta (alap)", 180, 5, 28, 5, "pancake", "palacsinta"),
            E("hu_gofri", "Gofri", 280, 6, 35, 13, "waffle"),
            E("hu_toast_sonka", "Sonkás-sajtos toast", 280, 14, 24, 14, "melegszendvics"),
            E("hu_granola_jog", "Müzli joghurttal", 150, 6, 22, 4),
            E("hu_protein", "Fehérjepor (vanília)", 380, 77, 10, 4, "protein powder", "whey", "fehérje por"),
            E("hu_protein_szelet", "Fehérjeszelet", 350, 30, 30, 12, "protein bar"),
            E("hu_kreatin", "Kreatin", 0, 0, 0, 0, "creatine"),
            E("hu_rizskása", "Rizskása", 120, 3, 22, 2, "rice pudding light"),
            E("hu_tejberizs", "Tejberizs", 130, 3.5, 22, 3, "rice pudding"),
            E("hu_tejbegriz", "Tejbegríz", 120, 3.5, 20, 3, "semolina pudding", "gríz"),
            E("hu_turorudi", "Túró rudi", 380, 12, 40, 18, "turorudi"),
            E("hu_kakaoscsiga", "Kakaós csiga", 380, 7, 50, 16),
            E("hu_kifli_vaj", "Vajas kifli", 340, 7, 40, 17),
            E("hu_korozott", "Körözött", 250, 10, 3, 22, "liptauer"),
            E("hu_padlizsankrem", "Padlizsánkrém", 120, 2, 8, 9, "ajvár", "ajvar"),
            E("hu_hummusz", "Hummusz", 166, 8, 14, 10, "hummus", "homusz"),
            E("hu_etcsoki", "Étcsokoládé (70%)", 598, 7.8, 46, 43, "dark chocolate", "étcsoki", "csoki"),
            E("hu_tejcsoki", "Tejcsokoládé", 535, 7.7, 60, 30, "milk chocolate", "tejcsoki"),
            E("hu_mez", "Méz", 304, 0.3, 82, 0, "honey"),
            E("hu_cukor", "Cukor", 387, 0, 100, 0, "sugar"),
            E("hu_lekvar", "Lekvár", 250, 0.4, 62, 0.1, "jam", "dzsem"),
            E("hu_nutella", "Mogyorókrém", 539, 6, 57, 31, "nutella", "csokikrém"),
            E("hu_kremes", "Krémes", 280, 4, 35, 14),
            E("hu_somloi", "Somlói galuska", 290, 5, 40, 12, "somlói"),
            E("hu_dobos", "Dobostorta", 380, 5, 45, 20, "dobos torta"),
            E("hu_egeshtorta", "Eszterházy torta", 390, 6, 40, 22, "eszterházy"),
            E("hu_rejtes", "Rétes (almás)", 280, 4, 40, 12, "strudel", "almás rétes"),
            E("hu_fank", "Fánk", 380, 6, 45, 20, "donut", "farsangi fánk"),
            E("hu_kurtos", "Kürtőskalács", 360, 6, 55, 13, "chimney cake"),
            E("hu_langos", "Lángos", 310, 6, 40, 14, "langos", "lángos sajttal"),
            E("hu_pogacsa_tejfol", "Tejfölös pogácsa", 400, 8, 38, 24),
            E("hu_linzer", "Linzer karika", 450, 5, 55, 24),
            E("hu_zserbo", "Zserbó", 420, 5, 48, 22, "gerbeaud"),
            E("hu_fagylalt", "Fagylalt (vanília)", 200, 3.5, 24, 10, "ice cream", "jégkrém"),
            E("hu_sorbet", "Sorbet", 120, 0.5, 30, 0, "jégkása"),
            E("hu_viz", "Víz", 0, 0, 0, 0, "water", "ásványvíz"),
            E("hu_asvany", "Szénsavas víz", 0, 0, 0, 0, "sparkling water"),
            E("hu_kave", "Kávé (fekete)", 2, 0.1, 0, 0, "coffee", "espresso", "fekete kávé"),
            E("hu_tejeskave", "Tejeskávé", 45, 2, 5, 1.5, "latte", "cappuccino", "tejes kávé"),
            E("hu_tea", "Tea", 1, 0, 0, 0, "fekete tea", "zöld tea"),
            E("hu_narancsle", "Narancslé", 45, 0.7, 10, 0.2, "orange juice", "friss narancslé"),
            E("hu_almale", "Almalé", 46, 0.1, 11, 0.1, "apple juice"),
            E("hu_udito", "Üdítő (cola)", 42, 0, 10.6, 0, "cola", "coca cola", "üdítő", "szóda cukros"),
            E("hu_zero", "Cola zero", 0.5, 0, 0, 0, "zero cola", "light üdítő"),
            E("hu_smoothie", "Gyümölcssmoothie", 60, 1, 13, 0.5, "smoothie"),
            E("hu_feherjeital", "Fehérjeital", 80, 20, 4, 1.5, "protein shake"),
            E("hu_sor", "Sör", 43, 0.5, 3.6, 0, "beer", "világos sör"),
            E("hu_bor", "Vörösbor", 85, 0.1, 2.6, 0, "red wine", "bor"),
            E("hu_feherbor", "Fehérbor", 82, 0.1, 2.6, 0, "white wine"),
            E("hu_pezsgo", "Pezsgő", 85, 0.1, 3, 0, "champagne", "prosecco"),
            E("hu_palinka", "Pálinka", 250, 0, 0, 0, "rövidital"),
            E("hu_rizsteszta", "Rizstészta (főtt)", 110, 2, 25, 0.2, "rice noodles"),
            E("hu_glasnoodles", "Üvegtészta", 90, 0.2, 22, 0, "glass noodles"),
            E("hu_tofu", "Tofu", 76, 8, 2, 4.8),
            E("hu_tempeh", "Tempeh", 190, 20, 8, 11),
            E("hu_seitan", "Seitan", 140, 25, 8, 2),
            E("hu_szosz_parad", "Paradicsomszósz", 30, 1.2, 6, 0.2, "tomato sauce", "ketchup light"),
            E("hu_ketchup", "Ketchup", 110, 1, 25, 0.1),
            E("hu_mustar", "Mustár", 66, 4, 5, 3.5, "mustard"),
            E("hu_majon", "Majonéz", 680, 1, 1, 75, "mayo", "mayonnaise"),
            E("hu_lightmajon", "Light majonéz", 280, 1, 8, 27),
            E("hu_soja", "Szójaszósz", 60, 6, 6, 0, "soy sauce"),
            E("hu_pesto", "Pesto", 420, 5, 6, 42),
            E("hu_bolognai", "Bolognai szósz", 120, 8, 6, 7, "bolognese", "spagetti bolognai"),
            E("hu_carbonara", "Carbonara", 250, 12, 20, 14),
            E("hu_lasagne", "Lasagne", 160, 9, 14, 7, "lasagna"),
            E("hu_rantottcsirkecomb", "Rántott csirkecomb", 250, 18, 12, 14),
            E("hu_grillezettcsirke", "Grillezett csirkemell", 140, 28, 0, 3, "grill csirke", "grilled chicken"),
            E("hu_sultlazac", "Sült lazac", 220, 22, 0, 14, "grilled salmon"),
            E("hu_tonhalsalata", "Tonhalsaláta", 140, 14, 4, 7),
            E("hu_tojasos", "Tojásos nokedli", 170, 7, 22, 6),
            E("hu_bundaskenyer", "Bundás kenyér", 250, 9, 28, 11, "french toast"),
            E("hu_mezeskenyer", "Mézes kenyér", 300, 6, 55, 6, "kenyér mézzel"),
        ];

        public static int Count => All.Count;

        public static List<FoodItem> Search(string query, int max = 12)
        {
            string norm = Norm(query);
            if (norm.Length < 2) return [];

            var tokens = norm.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            string english = Norm(SearchQueryTranslator.ToEnglish(query));
            var engTokens = english.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

            return All
                .Select(e => (Entry: e, Score: Score(e, norm, tokens, english, engTokens)))
                .Where(x => x.Score >= 40)
                .OrderByDescending(x => x.Score)
                .ThenBy(x => x.Entry.Name.Length)
                .Take(max)
                .Select(x => x.Entry.ToFoodItem())
                .ToList();
        }

        private static int Score(Entry e, string norm, string[] tokens, string english, string[] engTokens)
        {
            var names = new List<string> { Norm(e.Name) };
            foreach (var a in e.Aliases) names.Add(Norm(a));

            int best = 0;
            foreach (var name in names)
            {
                int score = 0;
                if (name == norm || name == english) score = 100;
                else if (name.StartsWith(norm, StringComparison.Ordinal) ||
                         (english.Length >= 3 && name.StartsWith(english, StringComparison.Ordinal))) score = 85;
                else if (name.Contains(norm, StringComparison.Ordinal) ||
                         (english.Length >= 3 && name.Contains(english, StringComparison.Ordinal))) score = 70;
                else if (tokens.Length > 0 && tokens.All(t => name.Contains(t, StringComparison.Ordinal))) score = 55;
                else if (engTokens.Length > 0 &&
                         engTokens.All(t => t.Length < 3 || name.Contains(t, StringComparison.Ordinal)) &&
                         engTokens.Any(t => t.Length >= 3 && name.Contains(t, StringComparison.Ordinal))) score = 50;
                else if (tokens.Any(t => t.Length >= 4 && name.Contains(t, StringComparison.Ordinal))) score = 42;
                if (score > best) best = score;
            }
            return best;
        }

        private static string Norm(string s)
        {
            if (string.IsNullOrWhiteSpace(s)) return "";
            s = s.Trim().ToLowerInvariant();
            return s.Replace('á','a').Replace('é','e').Replace('í','i')
                     .Replace('ó','o').Replace('ö','o').Replace('ő','o')
                     .Replace('ú','u').Replace('ü','u').Replace('ű','u');
        }
    }
}
