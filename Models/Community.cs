namespace FitnessBackend.Models
{
    // Közösségi poszt: szelfi + befejezett edzés + megye
    public class CommunityPost
    {
        public string Id { get; set; } = "";
        public string UserName { get; set; } = "";
        public string Megye { get; set; } = "";
        public string Regio { get; set; } = "";
        public string SelfieUrl { get; set; } = "";
        public DateTime Megosztva { get; set; }
        public WorkoutSession Edzes { get; set; } = new WorkoutSession();
        public int LikeSzam { get; set; }
        public List<string> Likeolok { get; set; } = new List<string>();
        public List<CommunityComment> Kommentek { get; set; } = new List<CommunityComment>();
    }

    public class CommunityComment
    {
        public string Id { get; set; } = "";
        public string UserName { get; set; } = "";
        public string Szoveg { get; set; } = "";
        public DateTime Idobelyeg { get; set; }
    }

    // Telefon küldi edzés után: szelfi + megye + edzés adatok
    public class MegosztasKeres
    {
        public string UserName { get; set; } = "";
        public string Megye { get; set; } = "";
        public string SelfieUrl { get; set; } = "";
        public WorkoutSession Edzes { get; set; } = new WorkoutSession();
    }

    public class KommentKeres
    {
        public string UserName { get; set; } = "";
        public string Szoveg { get; set; } = "";
    }

    public class LikeKeres
    {
        public string UserName { get; set; } = "";
    }

    public class MegyeInfo
    {
        public string Id { get; set; } = "";
        public string Nev { get; set; } = "";
        public string Regio { get; set; } = "";
    }

    // Követés model
    public class KovetesInfo
    {
        public string Koveto { get; set; } = "";
        public string Kovetett { get; set; } = "";
        public DateTime Ota { get; set; }
    }

    public static class CommunityTarolo
    {
        public static List<CommunityPost> Posztok { get; } = UjSeedPosztok();
        public static List<KovetesInfo> Kovetek { get; } = new();

        public static bool KoveteEllenorzes(string koveto, string kovetett)
            => Kovetek.Any(k => k.Koveto == koveto && k.Kovetett == kovetett);

        private static List<CommunityPost> UjSeedPosztok()
        {
            var lista = new List<CommunityPost>();
            var most = DateTime.Now;

            lista.Add(new CommunityPost
            {
                Id = "post_seed001",
                UserName = "kovacs_bence",
                Megye = "Budapest",
                Regio = "Kozep-Magyarorszag",
                SelfieUrl = "",
                Megosztva = most.AddHours(-1.5),
                LikeSzam = 14,
                Likeolok = new List<string> { "nagy_petra", "toth_david", "szabo_aniko" },
                Kommentek = new List<CommunityComment>
                {
                    new() { Id = "k1", UserName = "nagy_petra", Szoveg = "Szép edzés! 💪", Idobelyeg = most.AddHours(-1) },
                    new() { Id = "k2", UserName = "toth_david", Szoveg = "Brutális volumen, respect!", Idobelyeg = most.AddMinutes(-40) }
                },
                Edzes = new WorkoutSession
                {
                    Id = 1001,
                    Title = "Push – Mellkas & Tricepsz",
                    IsActive = false,
                    StartTime = most.AddHours(-3),
                    Exercises = new List<LoggedExercise>
                    {
                        new() { ExerciseId = "bench-press", ExerciseName = "Fekvenyomás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=80, Reps=10, Elvegezve=true },
                            new() { SetNumber=2, Weight=90, Reps=8, Elvegezve=true },
                            new() { SetNumber=3, Weight=100, Reps=6, Elvegezve=true },
                        }},
                        new() { ExerciseId = "incline-dumbbell-press", ExerciseName = "Dőlt súlyzós mellnyomás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=30, Reps=12, Elvegezve=true },
                            new() { SetNumber=2, Weight=32, Reps=10, Elvegezve=true },
                        }},
                        new() { ExerciseId = "tricep-pushdown", ExerciseName = "Tricepsz lehúzás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=35, Reps=15, Elvegezve=true },
                            new() { SetNumber=2, Weight=40, Reps=12, Elvegezve=true },
                        }}
                    }
                }
            });

            lista.Add(new CommunityPost
            {
                Id = "post_seed002",
                UserName = "nagy_petra",
                Megye = "Pest",
                Regio = "Kozep-Magyarorszag",
                SelfieUrl = "",
                Megosztva = most.AddHours(-4),
                LikeSzam = 22,
                Likeolok = new List<string> { "kovacs_bence", "molnar_zoli", "kiss_reka", "varga_mark" },
                Kommentek = new List<CommunityComment>
                {
                    new() { Id = "k3", UserName = "molnar_zoli", Szoveg = "Menő húzós nap! Mekkora az 1RM-ed?", Idobelyeg = most.AddHours(-3.5) },
                    new() { Id = "k4", UserName = "nagy_petra", Szoveg = "Kb. 80 kg, még dolgozok rajta 😅", Idobelyeg = most.AddHours(-3) }
                },
                Edzes = new WorkoutSession
                {
                    Id = 1002,
                    Title = "Pull – Hát & Bicepsz",
                    IsActive = false,
                    StartTime = most.AddHours(-6),
                    Exercises = new List<LoggedExercise>
                    {
                        new() { ExerciseId = "deadlift", ExerciseName = "Felhúzás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=60, Reps=8, Elvegezve=true },
                            new() { SetNumber=2, Weight=70, Reps=6, Elvegezve=true },
                            new() { SetNumber=3, Weight=75, Reps=5, Elvegezve=true },
                        }},
                        new() { ExerciseId = "lat-pulldown", ExerciseName = "Lat húzás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=50, Reps=12, Elvegezve=true },
                            new() { SetNumber=2, Weight=55, Reps=10, Elvegezve=true },
                        }},
                        new() { ExerciseId = "barbell-curl", ExerciseName = "Rúd bicepsz hajlítás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=25, Reps=12, Elvegezve=true },
                            new() { SetNumber=2, Weight=30, Reps=10, Elvegezve=true },
                        }}
                    }
                }
            });

            lista.Add(new CommunityPost
            {
                Id = "post_seed003",
                UserName = "molnar_zoli",
                Megye = "Győr-Moson-Sopron",
                Regio = "Nyugat-Dunantul",
                SelfieUrl = "",
                Megosztva = most.AddHours(-8),
                LikeSzam = 9,
                Likeolok = new List<string> { "toth_david", "kiss_reka" },
                Kommentek = new List<CommunityComment>
                {
                    new() { Id = "k5", UserName = "kiss_reka", Szoveg = "Lábnapot sajnálom, de klassz! 🦵", Idobelyeg = most.AddHours(-7) }
                },
                Edzes = new WorkoutSession
                {
                    Id = 1003,
                    Title = "Legs – Guggolás fókusz",
                    IsActive = false,
                    StartTime = most.AddHours(-10),
                    Exercises = new List<LoggedExercise>
                    {
                        new() { ExerciseId = "squat", ExerciseName = "Guggolás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=100, Reps=8, Elvegezve=true },
                            new() { SetNumber=2, Weight=110, Reps=6, Elvegezve=true },
                            new() { SetNumber=3, Weight=120, Reps=4, Elvegezve=true },
                        }},
                        new() { ExerciseId = "leg-press", ExerciseName = "Lábtoló", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=150, Reps=12, Elvegezve=true },
                            new() { SetNumber=2, Weight=170, Reps=10, Elvegezve=true },
                        }},
                        new() { ExerciseId = "leg-curl", ExerciseName = "Combhajlítás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=40, Reps=15, Elvegezve=true },
                            new() { SetNumber=2, Weight=45, Reps=12, Elvegezve=true },
                        }}
                    }
                }
            });

            lista.Add(new CommunityPost
            {
                Id = "post_seed004",
                UserName = "kiss_reka",
                Megye = "Hajdú-Bihar",
                Regio = "Eszak-Alfold",
                SelfieUrl = "",
                Megosztva = most.AddDays(-1).AddHours(2),
                LikeSzam = 31,
                Likeolok = new List<string> { "kovacs_bence", "nagy_petra", "molnar_zoli", "varga_mark", "toth_david" },
                Kommentek = new List<CommunityComment>
                {
                    new() { Id = "k6", UserName = "varga_mark", Szoveg = "Wow az OHP szám komoly!", Idobelyeg = most.AddDays(-1).AddHours(3) },
                    new() { Id = "k7", UserName = "kovacs_bence", Szoveg = "Beast mode! 🔥", Idobelyeg = most.AddDays(-1).AddHours(4) }
                },
                Edzes = new WorkoutSession
                {
                    Id = 1004,
                    Title = "Shoulder & Core",
                    IsActive = false,
                    StartTime = most.AddDays(-1),
                    Exercises = new List<LoggedExercise>
                    {
                        new() { ExerciseId = "overhead-press", ExerciseName = "Nyomás felett (OHP)", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=50, Reps=8, Elvegezve=true },
                            new() { SetNumber=2, Weight=55, Reps=7, Elvegezve=true },
                            new() { SetNumber=3, Weight=60, Reps=5, Elvegezve=true },
                        }},
                        new() { ExerciseId = "lateral-raise", ExerciseName = "Oldalsó emelés", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=10, Reps=15, Elvegezve=true },
                            new() { SetNumber=2, Weight=12, Reps=12, Elvegezve=true },
                        }}
                    }
                }
            });

            lista.Add(new CommunityPost
            {
                Id = "post_seed005",
                UserName = "varga_mark",
                Megye = "Bács-Kiskun",
                Regio = "Del-Alfold",
                SelfieUrl = "",
                Megosztva = most.AddDays(-1).AddHours(-3),
                LikeSzam = 7,
                Likeolok = new List<string> { "nagy_petra" },
                Kommentek = new List<CommunityComment>(),
                Edzes = new WorkoutSession
                {
                    Id = 1005,
                    Title = "Full Body – erő + kondíció",
                    IsActive = false,
                    StartTime = most.AddDays(-1).AddHours(-5),
                    Exercises = new List<LoggedExercise>
                    {
                        new() { ExerciseId = "bench-press", ExerciseName = "Fekvenyomás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=70, Reps=10, Elvegezve=true },
                            new() { SetNumber=2, Weight=75, Reps=8, Elvegezve=true },
                        }},
                        new() { ExerciseId = "squat", ExerciseName = "Guggolás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=90, Reps=8, Elvegezve=true },
                            new() { SetNumber=2, Weight=100, Reps=6, Elvegezve=true },
                        }},
                        new() { ExerciseId = "deadlift", ExerciseName = "Felhúzás", Sets = new List<LoggedSet>
                        {
                            new() { SetNumber=1, Weight=110, Reps=5, Elvegezve=true },
                            new() { SetNumber=2, Weight=120, Reps=4, Elvegezve=true },
                        }}
                    }
                }
            });

            return lista;
        }

        public static readonly List<MegyeInfo> MagyarMegyek = new List<MegyeInfo>
        {
            new() { Id = "budapest", Nev = "Budapest", Regio = "Kozep-Magyarorszag" },
            new() { Id = "pest", Nev = "Pest", Regio = "Kozep-Magyarorszag" },
            new() { Id = "fejer", Nev = "Fejér", Regio = "Kozep-Magyarorszag" },
            new() { Id = "komarom_esztergom", Nev = "Komárom-Esztergom", Regio = "Kozep-Dunantul" },
            new() { Id = "veszprem", Nev = "Veszprém", Regio = "Kozep-Dunantul" },
            new() { Id = "gyor_moson_sopron", Nev = "Győr-Moson-Sopron", Regio = "Nyugat-Dunantul" },
            new() { Id = "vas", Nev = "Vas", Regio = "Nyugat-Dunantul" },
            new() { Id = "zala", Nev = "Zala", Regio = "Nyugat-Dunantul" },
            new() { Id = "somogy", Nev = "Somogy", Regio = "Del-Dunantul" },
            new() { Id = "tolna", Nev = "Tolna", Regio = "Del-Dunantul" },
            new() { Id = "baranya", Nev = "Baranya", Regio = "Del-Dunantul" },
            new() { Id = "bacs_kiskun", Nev = "Bács-Kiskun", Regio = "Del-Alfold" },
            new() { Id = "csongrad_csanad", Nev = "Csongrád-Csanád", Regio = "Del-Alfold" },
            new() { Id = "bekes", Nev = "Békés", Regio = "Del-Alfold" },
            new() { Id = "jasz_nagykun_szolnok", Nev = "Jász-Nagykun-Szolnok", Regio = "Eszak-Alfold" },
            new() { Id = "hajdu_bihar", Nev = "Hajdú-Bihar", Regio = "Eszak-Alfold" },
            new() { Id = "szabolcs_szatmar_bereg", Nev = "Szabolcs-Szatmár-Bereg", Regio = "Eszak-Alfold" },
            new() { Id = "heves", Nev = "Heves", Regio = "Eszak-Magyarorszag" },
            new() { Id = "nograd", Nev = "Nógrád", Regio = "Eszak-Magyarorszag" },
            new() { Id = "borsod_abauj_zemplen", Nev = "Borsod-Abaúj-Zemplén", Regio = "Eszak-Magyarorszag" }
        };

        public static (CommunityPost? poszt, string? hiba) UjPosztLetrehozasa(MegosztasKeres keres)
        {
            if (string.IsNullOrWhiteSpace(keres.UserName))
            {
                return (null, "UserName kotelezo.");
            }

            if (string.IsNullOrWhiteSpace(keres.Megye))
            {
                return (null, "Megye kotelezo.");
            }

            var megye_info = MagyarMegyek.FirstOrDefault(m =>
                m.Id.Equals(keres.Megye, StringComparison.OrdinalIgnoreCase) ||
                m.Nev.Equals(keres.Megye, StringComparison.OrdinalIgnoreCase));

            if (megye_info == null)
            {
                return (null, "Ismeretlen megye. Hasznald: GET /api/community/megyek");
            }

            if (keres.Edzes == null || keres.Edzes.Exercises.Count == 0)
            {
                return (null, "Az edzes adatok kotelezoek (legalabb 1 gyakorlat).");
            }

            var uj_poszt = new CommunityPost
            {
                Id = $"post_{Guid.NewGuid().ToString("N")[..8]}",
                UserName = keres.UserName,
                Megye = megye_info.Nev,
                Regio = megye_info.Regio,
                SelfieUrl = keres.SelfieUrl,
                Megosztva = DateTime.Now,
                Edzes = keres.Edzes
            };

            Posztok.Insert(0, uj_poszt);
            return (uj_poszt, null);
        }
    }
}
