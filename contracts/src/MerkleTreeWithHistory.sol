// https://tornado.cash
/*
 * d888888P                                           dP              a88888b.                   dP
 *    88                                              88             d8'   `88                   88
 *    88    .d8888b. 88d888b. 88d888b. .d8888b. .d888b88 .d8888b.    88        .d8888b. .d8888b. 88d888b.
 *    88    88'  `88 88'  `88 88'  `88 88'  `88 88'  `88 88'  `88    88        88'  `88 Y8ooooo. 88'  `88
 *    88    88.  .88 88       88    88 88.  .88 88.  .88 88.  .88 dP Y8.   .88 88.  .88       88 88    88
 *    dP    `88888P' dP       dP    dP `88888P8 `88888P8 `88888P' 88  Y88888P' `88888P8 `88888P' dP    dP
 * ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IHasher {
    function poseidon(
        uint256[2] calldata inputs
    ) external pure returns (uint256 x);
}

contract MerkleTreeWithHistory {
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 public constant ZERO_VALUE = 0;
    IHasher public immutable hasher;

    uint32 public levels;

    // the following variables are made public for easier testing and debugging and
    // are not supposed to be accessed in regular code

    // filledSubtrees and roots could be bytes32[size], but using mappings makes it cheaper because
    // it removes index range check on every interaction
    mapping(uint256 => bytes32) public filledSubtrees;
    mapping(uint256 => bytes32) public roots;
    uint32 public constant ROOT_HISTORY_SIZE = 30;
    uint32 public currentRootIndex = 0;
    uint32 public nextIndex = 0;

    constructor(uint32 _levels, IHasher _hasher) {
        require(_levels > 0, "_levels should be greater than zero");
        require(_levels < 32, "_levels should be less than 32");
        levels = _levels;
        hasher = _hasher;

        for (uint32 i = 0; i < _levels; i++) {
            filledSubtrees[i] = zeros(i);
        }

        roots[0] = zeros(_levels);
    }

    /**
     * @dev Hash 2 tree leaves, returns Poseidon(_left, _right)
     */
    function hashLeftRight(
        IHasher _hasher,
        bytes32 _left,
        bytes32 _right
    ) public pure returns (bytes32) {
        require(
            uint256(_left) < FIELD_SIZE,
            "_left should be inside the field"
        );
        require(
            uint256(_right) < FIELD_SIZE,
            "_right should be inside the field"
        );
        uint256 R = uint256(_right);
        uint256 L = uint256(_left);
        return bytes32(_hasher.poseidon([L, R]));
    }

    function _insert(bytes32 _leaf) internal returns (uint32 index) {
        uint32 _nextIndex = nextIndex;
        require(
            _nextIndex != uint32(2) ** levels,
            "Merkle tree is full. No more leaves can be added"
        );
        uint32 currentIndex = _nextIndex;
        bytes32 currentLevelHash = _leaf;
        bytes32 left;
        bytes32 right;

        for (uint32 i = 0; i < levels; i++) {
            if (currentIndex % 2 == 0) {
                left = currentLevelHash;
                right = zeros(i);
                filledSubtrees[i] = currentLevelHash;
            } else {
                left = filledSubtrees[i];
                right = currentLevelHash;
            }
            currentLevelHash = hashLeftRight(hasher, left, right);
            currentIndex /= 2;
        }

        uint32 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        currentRootIndex = newRootIndex;
        roots[newRootIndex] = currentLevelHash;
        nextIndex = _nextIndex + 1;
        return _nextIndex;
    }

    /**
     * @dev Whether the root is present in the root history
     */
    function isKnownRoot(bytes32 _root) public view returns (bool) {
        if (_root == 0) {
            return false;
        }
        uint32 _currentRootIndex = currentRootIndex;
        uint32 i = _currentRootIndex;
        do {
            if (_root == roots[i]) {
                return true;
            }
            if (i == 0) {
                i = ROOT_HISTORY_SIZE;
            }
            i--;
        } while (i != _currentRootIndex);
        return false;
    }

    /**
     * @dev Returns the last root
     */
    function getLastRoot() public view returns (bytes32) {
        return roots[currentRootIndex];
    }

    uint256 internal constant Z_0 = 0;
    uint256 internal constant Z_1 =
        14744269619966411208579211824598458697587494354926760081771325075741142829156;
    uint256 internal constant Z_2 =
        7423237065226347324353380772367382631490014989348495481811164164159255474657;
    uint256 internal constant Z_3 =
        11286972368698509976183087595462810875513684078608517520839298933882497716792;
    uint256 internal constant Z_4 =
        3607627140608796879659380071776844901612302623152076817094415224584923813162;
    uint256 internal constant Z_5 =
        19712377064642672829441595136074946683621277828620209496774504837737984048981;
    uint256 internal constant Z_6 =
        20775607673010627194014556968476266066927294572720319469184847051418138353016;
    uint256 internal constant Z_7 =
        3396914609616007258851405644437304192397291162432396347162513310381425243293;
    uint256 internal constant Z_8 =
        21551820661461729022865262380882070649935529853313286572328683688269863701601;
    uint256 internal constant Z_9 =
        6573136701248752079028194407151022595060682063033565181951145966236778420039;
    uint256 internal constant Z_10 =
        12413880268183407374852357075976609371175688755676981206018884971008854919922;
    uint256 internal constant Z_11 =
        14271763308400718165336499097156975241954733520325982997864342600795471836726;
    uint256 internal constant Z_12 =
        20066985985293572387227381049700832219069292839614107140851619262827735677018;
    uint256 internal constant Z_13 =
        9394776414966240069580838672673694685292165040808226440647796406499139370960;
    uint256 internal constant Z_14 =
        11331146992410411304059858900317123658895005918277453009197229807340014528524;
    uint256 internal constant Z_15 =
        15819538789928229930262697811477882737253464456578333862691129291651619515538;
    uint256 internal constant Z_16 =
        19217088683336594659449020493828377907203207941212636669271704950158751593251;
    uint256 internal constant Z_17 =
        21035245323335827719745544373081896983162834604456827698288649288827293579666;
    uint256 internal constant Z_18 =
        6939770416153240137322503476966641397417391950902474480970945462551409848591;
    uint256 internal constant Z_19 =
        10941962436777715901943463195175331263348098796018438960955633645115732864202;
    uint256 internal constant Z_20 =
        15019797232609675441998260052101280400536945603062888308240081994073687793470;
    uint256 internal constant Z_21 =
        11702828337982203149177882813338547876343922920234831094975924378932809409969;
    uint256 internal constant Z_22 =
        11217067736778784455593535811108456786943573747466706329920902520905755780395;
    uint256 internal constant Z_23 =
        16072238744996205792852194127671441602062027943016727953216607508365787157389;
    uint256 internal constant Z_24 =
        17681057402012993898104192736393849603097507831571622013521167331642182653248;
    uint256 internal constant Z_25 =
        21694045479371014653083846597424257852691458318143380497809004364947786214945;
    uint256 internal constant Z_26 =
        8163447297445169709687354538480474434591144168767135863541048304198280615192;
    uint256 internal constant Z_27 =
        14081762237856300239452543304351251708585712948734528663957353575674639038357;
    uint256 internal constant Z_28 =
        16619959921569409661790279042024627172199214148318086837362003702249041851090;
    uint256 internal constant Z_29 =
        7022159125197495734384997711896547675021391130223237843255817587255104160365;
    uint256 internal constant Z_30 =
        4114686047564160449611603615418567457008101555090703535405891656262658644463;
    uint256 internal constant Z_31 =
        12549363297364877722388257367377629555213421373705596078299904496781819142130;
    uint256 internal constant Z_32 =
        21443572485391568159800782191812935835534334817699172242223315142338162256601;

    function zeros(uint256 index) internal pure returns (bytes32) {
        if (index == 0) return bytes32(Z_0);
        if (index == 1) return bytes32(Z_1);
        if (index == 2) return bytes32(Z_2);
        if (index == 3) return bytes32(Z_3);
        if (index == 4) return bytes32(Z_4);
        if (index == 5) return bytes32(Z_5);
        if (index == 6) return bytes32(Z_6);
        if (index == 7) return bytes32(Z_7);
        if (index == 8) return bytes32(Z_8);
        if (index == 9) return bytes32(Z_9);
        if (index == 10) return bytes32(Z_10);
        if (index == 11) return bytes32(Z_11);
        if (index == 12) return bytes32(Z_12);
        if (index == 13) return bytes32(Z_13);
        if (index == 14) return bytes32(Z_14);
        if (index == 15) return bytes32(Z_15);
        if (index == 16) return bytes32(Z_16);
        if (index == 17) return bytes32(Z_17);
        if (index == 18) return bytes32(Z_18);
        if (index == 19) return bytes32(Z_19);
        if (index == 20) return bytes32(Z_20);
        if (index == 21) return bytes32(Z_21);
        if (index == 22) return bytes32(Z_22);
        if (index == 23) return bytes32(Z_23);
        if (index == 24) return bytes32(Z_24);
        if (index == 25) return bytes32(Z_25);
        if (index == 26) return bytes32(Z_26);
        if (index == 27) return bytes32(Z_27);
        if (index == 28) return bytes32(Z_28);
        if (index == 29) return bytes32(Z_29);
        if (index == 30) return bytes32(Z_30);
        if (index == 31) return bytes32(Z_31);
        if (index == 32) return bytes32(Z_32);
        revert("WrongDefaultZeroIndex");
    }
}
