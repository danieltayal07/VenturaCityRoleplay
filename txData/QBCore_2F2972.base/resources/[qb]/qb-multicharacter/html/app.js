document.addEventListener("DOMContentLoaded", () => {
    if (typeof profList === 'undefined') var profList = [""];

    const viewmodel = new Vue({
        el: "#app",
        data: {
            characters: [],
            show: { loading: false, characters: false, register: false, delete: false },
            
            registerData: { date: "", firstname: "", lastname: "", nationality: "", gender: "Male" },
            
            currentTheme: '#FFD700',
            weather: 'Sunny',
            currentTime: '12:00',
            myId: 0,
            showNews: false,
            isCinematic: false,
            
            isScanning: false,
            scanText: "HOLD TO SCAN",
            scanTimer: null,

            // Audio Logic Updated
            isPlaying: false,
            audioEl: null,
            // ADD YOUR SONGS HERE
            songList: ["music1.mp3", "music2.mp3"], 
            currentSongIndex: 0,
            
            characterAmount: 0,
            loadingText: "",
            selectedCharacter: -1,
            dollar: Intl.NumberFormat("en-US"),
            allowDelete: false
        },
        computed: {
            currentSongName() { 
                // Displays "Music 1" instead of "music1.mp3"
                let name = this.songList[this.currentSongIndex].split('.')[0];
                return name.charAt(0).toUpperCase() + name.slice(1).replace(/(\d+)/g, ' $1');
            }
        },
        methods: {
            setTheme(color) {
                this.currentTheme = color;
                document.documentElement.style.setProperty('--primary', color);
            },
            changeCam(type) {
                axios.post("https://qb-multicharacter/changeCamera", { type: type });
            },
            toggleCinematic() {
                this.isCinematic = !this.isCinematic;
            },
            openLink(url) {
                window.invokeNative('openUrl', url);
            },
            startScan() {
                if(!this.registerData.firstname || !this.registerData.lastname) return;
                this.isScanning = true;
                this.scanText = "SCANNING...";
                this.scanTimer = setTimeout(() => { this.create_character(); }, 2000);
            },
            stopScan() {
                this.isScanning = false;
                this.scanText = "HOLD TO SCAN";
                clearTimeout(this.scanTimer);
            },
            
            // --- AUDIO CONTROLS FIXED ---
            initAudio() {
                this.audioEl = document.getElementById("audio-player");
                if(this.audioEl) {
                    this.audioEl.volume = 0.15;
                    this.audioEl.src = "sounds/" + this.songList[this.currentSongIndex]; // Ensure src is set
                    // Try auto play, if blocked, wait for click
                    this.audioEl.play().then(() => this.isPlaying = true).catch(() => {
                        document.addEventListener('click', this.unlockAudio, { once: true });
                    });
                }
            },
            unlockAudio() { if(this.audioEl) { this.audioEl.play(); this.isPlaying = true; } },
            
            toggleMusic() {
                if(!this.audioEl) return;
                if (this.isPlaying) {
                    this.audioEl.pause();
                } else {
                    this.audioEl.play();
                }
                this.isPlaying = !this.isPlaying;
            },
            
            nextSong() {
                if(!this.audioEl) return;
                // Increment index, loop back to 0 if at end
                this.currentSongIndex = (this.currentSongIndex + 1) % this.songList.length;
                this.audioEl.src = "sounds/" + this.songList[this.currentSongIndex];
                
                // If it was playing, keep playing. If paused, stay paused (or force play?)
                // Usually better to force play on change
                this.audioEl.play().then(() => {
                    this.isPlaying = true;
                }).catch(e => console.log("Audio play failed", e));
            },
            
            stopAudio() { if(this.audioEl) { this.audioEl.pause(); this.isPlaying = false; } },

            click_character(idx, type) {
                this.selectedCharacter = idx;
                this.changeCam('body');
                
                if (this.characters[idx]) {
                    axios.post("https://qb-multicharacter/cDataPed", { cData: this.characters[idx] });
                } else {
                    axios.post("https://qb-multicharacter/cDataPed", {});
                    if (type === "empty") {
                        this.registerData = { date: "", firstname: "", lastname: "", nationality: "", gender: "Male" };
                        this.show.characters = false;
                        this.show.register = true;
                    }
                }
            },
            create_character() {
                const r = this.registerData;
                this.show.register = false;
                this.show.loading = true;
                this.loadingText = "VERIFYING BIOMETRICS...";
                this.stopAudio();
                axios.post("https://qb-multicharacter/createNewCharacter", {
                    firstname: r.firstname, lastname: r.lastname,
                    nationality: r.nationality, birthdate: r.date,
                    gender: r.gender == 'Male' ? 0 : 1, cid: this.selectedCharacter
                });
                setTimeout(() => { this.show.loading = false; this.show.characters = false; }, 2000);
            },
            cancelCreate() {
                this.show.register = false;
                this.show.characters = true;
                this.click_character(this.selectedCharacter, 'existing');
            },
            play_character() {
                if (this.selectedCharacter !== -1 && this.characters[this.selectedCharacter]) {
                    this.loadingText = "ESTABLISHING CONNECTION...";
                    this.show.loading = true;
                    this.show.characters = false;
                    this.stopAudio();
                    axios.post("https://qb-multicharacter/selectCharacter", { cData: this.characters[this.selectedCharacter] });
                    setTimeout(() => { this.show.loading = false; }, 2000);
                }
            },
            delete_character_modal() {
                Swal.fire({
                    title: 'PERMANENT DELETION', text: "This cannot be undone.", icon: 'warning',
                    showCancelButton: true, confirmButtonColor: '#d33', confirmButtonText: 'DELETE',
                    background: '#111', color: '#fff'
                }).then((r) => { if(r.isConfirmed) this.delete_character(); });
            },
            delete_character() {
                axios.post("https://qb-multicharacter/removeCharacter", { citizenid: this.characters[this.selectedCharacter].citizenid });
                this.selectedCharacter = -1;
            }
        },
        mounted() {
            this.initAudio();
            window.addEventListener("message", (event) => {
                var data = event.data;
                if (data.action === "openUrl_response") window.open(data.url, '_blank');

                if (data.action === "ui") {
                    this.characterAmount = data.nChar;
                    this.allowDelete = data.enableDeleteButton;
                    if(data.weather) this.weather = data.weather;
                    if(data.time) this.currentTime = data.time;
                    if(data.myId) this.myId = data.myId;

                    if (data.toggle) {
                        this.show.loading = true;
                        this.loadingText = "INITIALIZING VENTURA v0.2...";
                        if(this.audioEl) { this.audioEl.currentTime = 0; this.audioEl.play().catch(()=>{}); this.isPlaying = true; }
                        
                        setTimeout(() => {
                            axios.post("https://qb-multicharacter/setupCharacters");
                            setTimeout(() => {
                                this.show.loading = false;
                                this.show.characters = true;
                                axios.post("https://qb-multicharacter/removeBlur");
                            }, 1000);
                        }, 1000);
                    }
                } else if (data.action === "setupCharacters") {
                    var newChars = [];
                    for (var i = 0; i < event.data.characters.length; i++) {
                        newChars[event.data.characters[i].cid] = event.data.characters[i];
                    }
                    this.characters = newChars;
                }
            });
        }
    });
});