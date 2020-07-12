pragma solidity 0.6.11;

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

contract DragonereumGalaxies is OwnableUpgradeSafe {
    using SafeMath for uint256;

    IERC20 public goldToken;

    uint256 public constant CREATION_PRICE = 10000 ether; // 10,000 GOLD
    uint256 public constant DEPLOYMENT_PRICE = 1000000 ether; // 1,000,000 GOLD
    address private constant BURN_ADDRESS = 0x0000000000000000000000000000000000000001;
    uint256 public constant FUNDING_DURATION = 90 days;

    struct Galaxy {
        string name;
        string description;
        string icon;
    }
    Galaxy[] galaxies;
    mapping (string => uint256) public idsByNames;
    mapping (uint256 => uint256) public galaxiesCreationTimestamps;
    mapping (uint256 => uint256) public galaxiesBalances;
    mapping (uint256 => bool) public destroyedGalaxies;
    mapping (uint256 => bool) public deployedGalaxies;
    mapping (uint256 => bool) public pausedGalaxies;
    mapping (uint256 => mapping (address => uint256)) public galaxiesContributorsBalances;

    modifier validId(uint256 _id) {
        require(_id != 0 && _id < galaxies.length, "the galaxy with this id doesn't exist");
        _;
    }

    modifier validName(string memory _name) {
        require(idsByNames[_name] == 0, "the galaxy with this name already exists");
        _;
    }

    modifier notDeployed(uint256 _id) {
        require(!deployedGalaxies[_id], "the galaxy is deployed");
        _;
    }

    modifier notDestroyed(uint256 _id) {
        require(!destroyedGalaxies[_id], "the galaxy is destroyed");
        _;
    }

    function initialize(address _goldToken, address _owner) external initializer {
        __Ownable_init();
        transferOwnership(_owner);
        goldToken = IERC20(_goldToken);
        galaxies.push(Galaxy("", "", ""));
        idsByNames[""] = 0;
    }

    function createGalaxy(string memory _name, string memory _description) public {
        createGalaxy(_name, _description, "");
    }

    function createGalaxy(string memory _name, string memory _description, string memory _icon) public validName(_name) {
        goldToken.transferFrom(msg.sender, address(this), CREATION_PRICE);
        galaxies.push(Galaxy(_name, _description, _icon));
        uint256 id = galaxies.length.sub(1);
        idsByNames[_name] = id;
        galaxiesContributorsBalances[id][msg.sender] = CREATION_PRICE;
        galaxiesBalances[id] = CREATION_PRICE;
        // solium-disable-next-line security/no-block-members
        galaxiesCreationTimestamps[id] = block.timestamp;
    }

    function fundGalaxy(uint256 _id, uint256 _amount) external validId(_id) notDeployed(_id) notDestroyed(_id) {
        require(!pausedGalaxies[_id], "the galaxy funding is paused");
        goldToken.transferFrom(msg.sender, address(this), _amount);
        galaxiesContributorsBalances[_id][msg.sender] = galaxiesContributorsBalances[_id][msg.sender].add(_amount);
        galaxiesBalances[_id] = galaxiesBalances[_id].add(_amount);
    }

    function destroyGalaxy(uint256 _id) external validId(_id) notDeployed(_id) onlyOwner {
        destroyedGalaxies[_id] = true;
    }

    function deployGalaxy(uint256 _id) external validId(_id) notDestroyed(_id) onlyOwner {
        uint256 galaxyBalance = galaxiesBalances[_id];
        require(galaxyBalance >= DEPLOYMENT_PRICE, "not enough funding");
        goldToken.transfer(BURN_ADDRESS, galaxyBalance);
        deployedGalaxies[_id] = true;
    }

    function updateGalaxy(
        uint256 _id,
        string calldata _name,
        string calldata _description,
        string calldata _icon
    ) external validId(_id) validName(_name) onlyOwner {
        galaxies[_id] = Galaxy(_name, _description, _icon);
    }

    function pauseFunding(uint256 _id) external validId(_id) onlyOwner {
        pausedGalaxies[_id] = true;
    }

    function unpauseFunding(uint256 _id) external validId(_id) onlyOwner {
        pausedGalaxies[_id] = false;
    }

    function returnFunds(uint256 _id) external validId(_id) notDeployed(_id) {
        require(
            // solium-disable-next-line security/no-block-members
            destroyedGalaxies[_id] || galaxiesCreationTimestamps[_id].add(FUNDING_DURATION) < block.timestamp,
            "funds are still locked"
        );
        uint256 userBalance = galaxiesContributorsBalances[_id][msg.sender];
        require(userBalance > 0, "nothing to return");
        goldToken.transfer(msg.sender, userBalance);
        galaxiesContributorsBalances[_id][msg.sender] = 0;
        galaxiesBalances[_id] = galaxiesBalances[_id].sub(userBalance);
    }

    function getGalaxy(uint256 _id) external view validId(_id) returns (
        string memory name,
        string memory description,
        string memory icon
    ) {
        return (galaxies[_id].name, galaxies[_id].description, galaxies[_id].icon);
    }
}
